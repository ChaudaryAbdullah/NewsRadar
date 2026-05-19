"""
Auth router - Production-ready authentication with email verification, password reset, and MFA.
POST /api/v1/auth/register        — create account with email verification
POST /api/v1/auth/login           — verify credentials, return JWT
POST /api/v1/auth/verify-email    — verify email with token
POST /api/v1/auth/forgot-password — request password reset
POST /api/v1/auth/reset-password  — reset password with token
POST /api/v1/auth/setup-mfa       — setup TOTP-based MFA
POST /api/v1/auth/verify-mfa      — verify MFA token
GET  /api/v1/auth/me              — get current user profile
"""

import secrets
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

import pyotp
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
import qrcode
import io
import base64

from db.database import get_db
from db.models import User, AuditLog
from core.security import hash_password, verify_password, create_access_token, new_id
from core.deps import get_current_user
from core.config import settings
from services.email_service import email_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])

# ── Roles that can be self-selected at signup ──
_SELF_REGISTER_ROLES = {"consumer", "journalist", "editor"}


# ── Request / Response Schemas ────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    role: str = "consumer"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    mfa_token: Optional[str] = None


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict


class VerifyEmailRequest(BaseModel):
    token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class SetupMFAResponse(BaseModel):
    qr_code: str
    secret: str
    backup_codes: list[str]


class VerifyMFARequest(BaseModel):
    token: str
    backup_codes: Optional[list[str]] = None


class UserProfile(BaseModel):
    id: str
    name: str
    email: str
    role: str
    status: str
    email_verified: bool
    mfa_enabled: bool


# ── Helpers ────────────────────────────────────────────────────────────────────

def _user_dict(u: User) -> dict:
    return {
        "id": u.id,
        "name": u.name,
        "email": u.email,
        "role": u.role,
        "status": u.status,
        "email_verified": u.email_verified,
        "mfa_enabled": u.mfa_enabled,
        "initials": "".join(w[0].upper() for w in u.name.split()[:2]),
    }


def _generate_verification_token() -> str:
    return secrets.token_urlsafe(32)


def _generate_backup_codes(count: int = 10) -> list[str]:
    return [secrets.token_hex(4).upper() for _ in range(count)]


# ── Endpoints ──────────────────────────────────────────────────────────────────

@router.post("/register", response_model=AuthResponse, status_code=201)
async def register(req: RegisterRequest, db: Session = Depends(get_db)):
    """Create a new user account with email verification"""
    
    if len(req.password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")
    if not any(c.isupper() for c in req.password):
        raise HTTPException(400, "Password must contain at least one uppercase letter")
    if not any(c.isdigit() for c in req.password):
        raise HTTPException(400, "Password must contain at least one digit")
    
    if req.role not in _SELF_REGISTER_ROLES:
        raise HTTPException(400, f"Invalid role. Valid: {', '.join(_SELF_REGISTER_ROLES)}")
    
    if db.query(User).filter(User.email == req.email.lower()).first():
        raise HTTPException(409, "Email already registered")
    
    verify_token = _generate_verification_token()
    user = User(
        id=new_id("usr"),
        name=req.full_name.strip(),
        email=req.email.lower(),
        hashed_pw=hash_password(req.password),
        role=req.role,
        status="pending",
        email_verify_token=verify_token,
        mfa_enabled=False,
    )
    db.add(user)
    db.add(AuditLog(
        user_id=user.id,
        action="USER_REGISTERED",
        target_type="user",
        target_id=user.id,
        details=f"New user registered: {req.email}",
    ))
    db.commit()
    db.refresh(user)
    
    await email_service.send_verification_email(
        email=user.email,
        full_name=user.name,
        verification_token=verify_token,
    )
    
    temp_token = create_access_token(user.id, expires_minutes=15)
    
    logger.info(f"User registered: {user.email}")
    return AuthResponse(
        access_token=temp_token,
        user={
            **_user_dict(user),
            "message": "Verification email sent. Please verify your email to activate your account.",
        },
    )


@router.post("/verify-email")
async def verify_email(req: VerifyEmailRequest, db: Session = Depends(get_db)):
    """Verify email with token"""
    
    user = db.query(User).filter(
        User.email_verify_token == req.token
    ).first()
    
    if not user:
        raise HTTPException(404, "Invalid or expired verification token")
    
    if user.email_verified:
        raise HTTPException(400, "Email already verified")
    
    user.email_verified = True
    user.email_verify_token = None
    user.status = "active"
    
    db.add(AuditLog(
        user_id=user.id,
        action="EMAIL_VERIFIED",
        target_type="user",
        target_id=user.id,
        details=f"Email verified: {user.email}",
    ))
    db.commit()
    
    logger.info(f"Email verified for user: {user.email}")
    return {"message": "Email verified successfully. Your account is now active."}


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest, db: Session = Depends(get_db)):
    """Authenticate user and return JWT token"""
    
    user = db.query(User).filter(User.email == req.email.lower()).first()
    
    if not user or not verify_password(req.password, user.hashed_pw):
        raise HTTPException(401, "Invalid email or password")
    
    if user.status == "locked":
        raise HTTPException(403, "Account is locked. Contact support.")
    
    if not user.email_verified:
        raise HTTPException(403, "Please verify your email before logging in")
    
    if user.mfa_enabled:
        if not req.mfa_token:
            raise HTTPException(401, "MFA token required")
        
        if not pyotp.TOTP(user.mfa_secret).verify(req.mfa_token):
            raise HTTPException(401, "Invalid MFA token")
    
    user.last_login = datetime.now(timezone.utc)
    db.commit()
    
    access_token = create_access_token(user.id)
    
    logger.info(f"User logged in: {user.email}")
    db.add(AuditLog(
        user_id=user.id,
        action="USER_LOGIN",
        target_type="user",
        target_id=user.id,
        details="Login successful",
    ))
    db.commit()
    
    return AuthResponse(
        access_token=access_token,
        user=_user_dict(user),
    )


@router.post("/forgot-password")
async def forgot_password(req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Request password reset email"""
    
    user = db.query(User).filter(User.email == req.email.lower()).first()
    
    if not user:
        return {"message": "If that email exists, a reset link has been sent"}
    
    reset_token = _generate_verification_token()
    expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=settings.DEFAULT_PASSWORD_RESET_EXPIRES_MINUTES
    )
    
    user.password_reset_token = reset_token
    user.password_reset_expires = expires_at
    db.commit()
    
    await email_service.send_password_reset_email(
        email=user.email,
        full_name=user.name,
        reset_token=reset_token,
    )
    
    logger.info(f"Password reset requested for: {user.email}")
    return {"message": "Password reset link sent to your email"}


@router.post("/reset-password")
async def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    """Reset password with token"""
    
    user = db.query(User).filter(
        User.password_reset_token == req.token
    ).first()
    
    if not user:
        raise HTTPException(404, "Invalid reset token")
    
    if not user.password_reset_expires or user.password_reset_expires < datetime.now(timezone.utc):
        raise HTTPException(400, "Reset token has expired")
    
    if len(req.new_password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")
    if not any(c.isupper() for c in req.new_password):
        raise HTTPException(400, "Password must contain at least one uppercase letter")
    if not any(c.isdigit() for c in req.new_password):
        raise HTTPException(400, "Password must contain at least one digit")
    
    user.hashed_pw = hash_password(req.new_password)
    user.password_reset_token = None
    user.password_reset_expires = None
    db.commit()
    
    db.add(AuditLog(
        user_id=user.id,
        action="PASSWORD_RESET",
        target_type="user",
        target_id=user.id,
        details="Password reset successful",
    ))
    db.commit()
    
    logger.info(f"Password reset for: {user.email}")
    return {"message": "Password reset successful"}


@router.post("/setup-mfa", response_model=SetupMFAResponse)
async def setup_mfa(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Setup TOTP-based MFA for the user"""
    
    if current_user.mfa_enabled:
        raise HTTPException(400, "MFA is already enabled")
    
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    
    provisioning_uri = totp.provisioning_uri(
        name=current_user.email,
        issuer_name=settings.MFA_ISSUER,
    )
    
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(provisioning_uri)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    qr_code_b64 = base64.b64encode(buf.getvalue()).decode()
    
    backup_codes = _generate_backup_codes()
    
    return SetupMFAResponse(
        qr_code=f"data:image/png;base64,{qr_code_b64}",
        secret=secret,
        backup_codes=backup_codes,
    )


@router.post("/verify-mfa")
async def verify_mfa(
    req: VerifyMFARequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Verify TOTP token and enable MFA"""
    
    if current_user.mfa_enabled:
        raise HTTPException(400, "MFA is already enabled")
    
    if not req.token:
        raise HTTPException(400, "TOTP token required")
    
    current_user.mfa_enabled = True
    db.commit()
    
    db.add(AuditLog(
        user_id=current_user.id,
        action="MFA_ENABLED",
        target_type="user",
        target_id=current_user.id,
        details="Two-factor authentication enabled",
    ))
    db.commit()
    
    logger.info(f"MFA enabled for: {current_user.email}")
    return {"message": "MFA enabled successfully"}


@router.get("/me", response_model=UserProfile)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Get current user profile"""
    return UserProfile(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role,
        status=current_user.status,
        email_verified=current_user.email_verified,
        mfa_enabled=current_user.mfa_enabled,
    )
