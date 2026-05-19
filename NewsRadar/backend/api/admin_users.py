"""
Admin — Users management (Production-ready)
GET    /api/v1/admin/users                    — list all users
POST   /api/v1/admin/users/invite             — invite a user (sends email)
GET    /api/v1/admin/users/invitations        — list pending invitations
POST   /api/v1/admin/users/invitations/accept — accept invitation
PATCH  /api/v1/admin/users/{id}/role         — change role
PATCH  /api/v1/admin/users/{id}/status       — lock / unlock
DELETE /api/v1/admin/users/{id}               — delete user
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import User, AuditLog, UserInvitation
from core.security import hash_password, new_id
from core.deps import require_admin, get_current_user
from core.config import settings
from services.email_service import email_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/admin/users", tags=["Admin — Users"])

VALID_ROLES = {"consumer", "journalist", "editor", "admin", "auditor"}
VALID_STATUSES = {"pending", "active", "locked", "archived"}


def _user_dict(u: User) -> dict:
    return {
        "id": u.id,
        "name": u.name,
        "email": u.email,
        "role": u.role,
        "status": u.status,
        "email_verified": u.email_verified,
        "mfa_enabled": u.mfa_enabled,
        "created_at": u.created_at.isoformat() if u.created_at else None,
        "last_login": u.last_login.isoformat() if u.last_login else None,
        "initials": "".join(w[0].upper() for w in u.name.split()[:2]),
    }


def _invitation_dict(inv: UserInvitation) -> dict:
    return {
        "id": inv.id,
        "email": inv.email,
        "full_name": inv.full_name,
        "role": inv.role,
        "status": inv.status,
        "invited_by": inv.invited_by.email if inv.invited_by else None,
        "created_at": inv.created_at.isoformat() if inv.created_at else None,
        "expires_at": inv.expires_at.isoformat() if inv.expires_at else None,
        "accepted_at": inv.accepted_at.isoformat() if inv.accepted_at else None,
    }


# ── List Users ────────────────────────────────────────────────────────────────

@router.get("")
async def list_users(
    skip: int = 0,
    limit: int = 50,
    role: Optional[str] = None,
    status: Optional[str] = None,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """List all users with optional filtering"""
    query = db.query(User)
    
    if role:
        query = query.filter(User.role == role)
    if status:
        query = query.filter(User.status == status)
    
    users = query.order_by(User.created_at.desc()).offset(skip).limit(limit).all()
    total = query.count()
    
    return {
        "users": [_user_dict(u) for u in users],
        "total": total,
        "skip": skip,
        "limit": limit,
    }


# ── Invite User ───────────────────────────────────────────────────────────────

class InviteRequest(BaseModel):
    full_name: str
    email: EmailStr
    role: str = "consumer"


@router.post("/invite", status_code=201)
async def invite_user(
    req: InviteRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Send invitation email to a new user"""
    
    if req.role not in VALID_ROLES:
        raise HTTPException(400, f"Invalid role. Valid: {', '.join(VALID_ROLES)}")
    
    # Check if already invited
    existing_invite = db.query(UserInvitation).filter(
        UserInvitation.email == req.email.lower(),
        UserInvitation.status.in_(["pending", "accepted"]),
    ).first()
    if existing_invite:
        raise HTTPException(409, "User already invited or registered")
    
    # Check if already registered
    if db.query(User).filter(User.email == req.email.lower()).first():
        raise HTTPException(409, "Email already registered")
    
    # Create invitation
    token = new_id("inv")
    expires_at = datetime.now(timezone.utc) + timedelta(
        hours=settings.DEFAULT_INVITE_EXPIRES_HOURS
    )
    
    invitation = UserInvitation(
        id=new_id("inv"),
        invited_by_id=admin.id,
        email=req.email.lower(),
        full_name=req.full_name.strip(),
        role=req.role,
        invitation_token=token,
        expires_at=expires_at,
        status="pending",
    )
    db.add(invitation)
    
    db.add(AuditLog(
        user_id=admin.id,
        action="USER_INVITED",
        target_type="user_invitation",
        target_id=invitation.id,
        details=f"Invited {req.email} as {req.role}",
    ))
    db.commit()
    db.refresh(invitation)
    
    # Send invitation email
    await email_service.send_invitation_email(
        email=invitation.email,
        full_name=invitation.full_name,
        role=invitation.role,
        invitation_token=token,
        invited_by=admin.name,
    )
    
    logger.info(f"Invitation sent to: {invitation.email}")
    return _invitation_dict(invitation)


# ── List Invitations ──────────────────────────────────────────────────────────

@router.get("/invitations")
async def list_invitations(
    status: Optional[str] = None,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """List all sent invitations"""
    query = db.query(UserInvitation)
    
    if status:
        query = query.filter(UserInvitation.status == status)
    
    invitations = query.order_by(UserInvitation.created_at.desc()).all()
    
    return {
        "invitations": [_invitation_dict(inv) for inv in invitations],
        "total": len(invitations),
    }


# ── Accept Invitation ─────────────────────────────────────────────────────────

class AcceptInvitationRequest(BaseModel):
    token: str
    password: str


@router.post("/invitations/accept", status_code=201)
async def accept_invitation(
    req: AcceptInvitationRequest,
    db: Session = Depends(get_db),
):
    """Accept invitation and create account"""
    
    invitation = db.query(UserInvitation).filter(
        UserInvitation.invitation_token == req.token
    ).first()
    
    if not invitation:
        raise HTTPException(404, "Invalid invitation token")
    
    if invitation.status != "pending":
        raise HTTPException(400, f"Invitation is {invitation.status}")
    
    if invitation.expires_at < datetime.now(timezone.utc):
        raise HTTPException(400, "Invitation has expired")
    
    # Validate password
    if len(req.password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")
    if not any(c.isupper() for c in req.password):
        raise HTTPException(400, "Password must contain at least one uppercase letter")
    if not any(c.isdigit() for c in req.password):
        raise HTTPException(400, "Password must contain at least one digit")
    
    # Create user
    user = User(
        id=new_id("usr"),
        name=invitation.full_name,
        email=invitation.email,
        hashed_pw=hash_password(req.password),
        role=invitation.role,
        status="active",
        email_verified=True,  # Email is verified via invitation
    )
    db.add(user)
    
    # Mark invitation as accepted
    invitation.status = "accepted"
    invitation.accepted_at = datetime.now(timezone.utc)
    
    db.add(AuditLog(
        user_id=user.id,
        action="INVITATION_ACCEPTED",
        target_type="user_invitation",
        target_id=invitation.id,
        details=f"User created from invitation",
    ))
    
    db.commit()
    db.refresh(user)
    
    logger.info(f"Invitation accepted by: {user.email}")
    return _user_dict(user)


# ── Update Role ───────────────────────────────────────────────────────────────

class RoleUpdateRequest(BaseModel):
    role: str


@router.patch("/{user_id}/role")
async def update_role(
    user_id: str,
    req: RoleUpdateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Change user role"""
    
    if req.role not in VALID_ROLES:
        raise HTTPException(400, f"Invalid role. Valid: {', '.join(VALID_ROLES)}")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    
    if user.id == admin.id:
        raise HTTPException(400, "Cannot change your own role")
    
    old_role = user.role
    user.role = req.role
    
    db.add(AuditLog(
        user_id=admin.id,
        action="USER_ROLE_CHANGED",
        target_type="user",
        target_id=user.id,
        details=f"Role changed: {old_role} → {req.role}",
    ))
    db.commit()
    
    logger.info(f"User {user.email} role changed to {req.role}")
    return _user_dict(user)


# ── Update Status ─────────────────────────────────────────────────────────────

class StatusUpdateRequest(BaseModel):
    status: str


@router.patch("/{user_id}/status")
async def update_status(
    user_id: str,
    req: StatusUpdateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Lock or unlock user account"""
    
    if req.status not in ("active", "locked", "archived"):
        raise HTTPException(400, "Status must be 'active', 'locked', or 'archived'")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    
    if user.id == admin.id:
        raise HTTPException(400, "Cannot change your own status")
    
    old_status = user.status
    user.status = req.status
    
    # Auto-verify email if admin activates them
    if req.status == "active" and not user.email_verified:
        user.email_verified = True
        user.email_verify_token = None
    
    db.add(AuditLog(
        user_id=admin.id,
        action=f"USER_{req.status.upper()}",
        target_type="user",
        target_id=user.id,
        details=f"Status changed: {old_status} → {req.status}",
    ))
    db.commit()
    
    logger.info(f"User {user.email} status changed to {req.status}")
    return _user_dict(user)


# ── Delete User ───────────────────────────────────────────────────────────────

@router.delete("/{user_id}", status_code=204)
async def delete_user(
    user_id: str,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Delete a user (archive is recommended over delete)"""
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    
    if user.id == admin.id:
        raise HTTPException(400, "Cannot delete yourself")
    
    if user.role == "admin":
        admin_count = db.query(User).filter(User.role == "admin").count()
        if admin_count <= 1:
            raise HTTPException(400, "Cannot delete the last admin")
    
    db.add(AuditLog(
        user_id=admin.id,
        action="USER_DELETED",
        target_type="user",
        target_id=user.id,
        details=f"User deleted by admin",
    ))
    db.delete(user)
    db.commit()
    
    logger.info(f"User deleted: {user.email}")
