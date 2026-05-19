"""
Admin — Sources management
GET    /api/v1/admin/sources        — list all sources
POST   /api/v1/admin/sources        — add new source
PATCH  /api/v1/admin/sources/{id}   — update (toggle active, reliability, etc.)
DELETE /api/v1/admin/sources/{id}   — remove source
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import Optional

from db.database import get_db
from db.models import Source, AuditLog, User
from core.security import new_id
from core.deps import require_admin

router = APIRouter(prefix="/api/v1/admin/sources", tags=["Admin — Sources"])

VALID_TYPES = {"RSS", "API", "SCRAPER"}


def _source_dict(s: Source) -> dict:
    return {
        "id":           s.id,
        "name":         s.name,
        "url":          s.url,
        "source_type":  s.source_type,
        "reliability":  s.reliability,
        "is_active":    s.is_active,
        "created_at":   s.created_at.isoformat() if s.created_at else None,
    }


@router.get("")
async def list_sources(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    sources = db.query(Source).order_by(Source.created_at).all()
    return {"sources": [_source_dict(s) for s in sources], "total": len(sources)}


class AddSourceRequest(BaseModel):
    name: str
    url: str
    source_type: str = "RSS"
    reliability: float = 0.70
    is_active: bool = True


@router.post("", status_code=201)
async def add_source(
    req: AddSourceRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if req.source_type not in VALID_TYPES:
        raise HTTPException(400, f"source_type must be one of: {', '.join(VALID_TYPES)}")
    if not (0.0 <= req.reliability <= 1.0):
        raise HTTPException(400, "reliability must be between 0.0 and 1.0")

    src = Source(
        id=new_id("src"),
        name=req.name.strip(),
        url=req.url.strip(),
        source_type=req.source_type,
        reliability=req.reliability,
        is_active=req.is_active,
    )
    db.add(src)
    db.add(AuditLog(
        user_id=admin.id, action="SOURCE_ADDED",
        target_type="source", target_id=src.id,
        details=f"Added source '{req.name}' by {admin.email}",
    ))
    db.commit()
    db.refresh(src)
    return _source_dict(src)


class UpdateSourceRequest(BaseModel):
    name: Optional[str] = None
    url: Optional[str] = None
    source_type: Optional[str] = None
    reliability: Optional[float] = None
    is_active: Optional[bool] = None


@router.patch("/{source_id}")
async def update_source(
    source_id: str,
    req: UpdateSourceRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    src = db.query(Source).filter(Source.id == source_id).first()
    if not src:
        raise HTTPException(404, "Source not found")

    if req.name is not None:        src.name = req.name.strip()
    if req.url is not None:         src.url = req.url.strip()
    if req.source_type is not None:
        if req.source_type not in VALID_TYPES:
            raise HTTPException(400, "Invalid source_type")
        src.source_type = req.source_type
    if req.reliability is not None:
        if not (0.0 <= req.reliability <= 1.0):
            raise HTTPException(400, "reliability must be 0.0–1.0")
        src.reliability = req.reliability
    if req.is_active is not None:   src.is_active = req.is_active

    db.add(AuditLog(
        user_id=admin.id, action="SOURCE_UPDATED",
        target_type="source", target_id=src.id,
        details=f"Updated by {admin.email}",
    ))
    db.commit()
    return _source_dict(src)


@router.delete("/{source_id}", status_code=204)
async def delete_source(
    source_id: str,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    src = db.query(Source).filter(Source.id == source_id).first()
    if not src:
        raise HTTPException(404, "Source not found")
    db.add(AuditLog(
        user_id=admin.id, action="SOURCE_DELETED",
        target_type="source", target_id=src.id,
        details=f"Deleted by {admin.email}",
    ))
    db.delete(src)
    db.commit()
