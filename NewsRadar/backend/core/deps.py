"""
FastAPI dependency — extracts and validates the Bearer JWT from the Authorization header.
Usage:
    @router.get("/protected")
    async def my_route(current_user: User = Depends(get_current_user)):
        ...

    @router.get("/admin-only")
    async def admin_route(current_user: User = Depends(require_admin)):
        ...
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import User
from core.security import decode_token

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if not creds:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    payload = decode_token(creds.credentials)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    user = db.query(User).filter(User.id == payload.get("sub")).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if user.status == "locked":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is locked")
    return user


def get_optional_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    """Returns user if authenticated, None otherwise (for public endpoints)."""
    if not creds:
        return None
    payload = decode_token(creds.credentials)
    if not payload:
        return None
    return db.query(User).filter(User.id == payload.get("sub")).first()


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


def require_editor(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role not in ("admin", "editor"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Editor access required")
    return current_user
