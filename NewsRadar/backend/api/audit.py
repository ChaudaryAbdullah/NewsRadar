"""
Audit Log API (admin/auditor only)
GET /api/v1/audit  — paginated audit log with optional filters
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import Optional

from db.database import get_db
from db.models import AuditLog, User
from core.deps import get_current_user

router = APIRouter(prefix="/api/v1/audit", tags=["Audit"])


def _log_dict(log: AuditLog) -> dict:
    return {
        "id":          log.id,
        "user_id":     log.user_id,
        "action":      log.action,
        "target_type": log.target_type,
        "target_id":   log.target_id,
        "details":     log.details,
        "created_at":  log.created_at.isoformat() if log.created_at else None,
        "user_name":   log.user.name if log.user else "System",
        "user_email":  log.user.email if log.user else None,
    }


@router.get("")
async def list_audit_logs(
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    action: Optional[str] = None,
    target_type: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in ("admin", "auditor"):
        from fastapi import HTTPException
        raise HTTPException(403, "Admin or Auditor access required")

    q = db.query(AuditLog)
    if action:
        q = q.filter(AuditLog.action.ilike(f"%{action}%"))
    if target_type:
        q = q.filter(AuditLog.target_type == target_type)

    total = q.count()
    logs = q.order_by(desc(AuditLog.created_at)).offset(offset).limit(limit).all()
    return {
        "logs":   [_log_dict(l) for l in logs],
        "total":  total,
        "limit":  limit,
        "offset": offset,
    }
