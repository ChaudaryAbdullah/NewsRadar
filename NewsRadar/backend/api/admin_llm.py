"""
LLM Config API (admin only)
GET /api/v1/admin/llm-config  — fetch current config
PUT /api/v1/admin/llm-config  — save/update config
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import Optional

from db.database import get_db
from db.models import LLMConfig, AuditLog, User
from core.deps import require_admin

router = APIRouter(prefix="/api/v1/admin/llm-config", tags=["Admin — LLM Config"])


def _config_dict(c: LLMConfig) -> dict:
    return {
        "provider":    c.provider,
        "model_summ":  c.model_summ,
        "model_ner":   c.model_ner,
        "model_sent":  c.model_sent,
        "model_claim": c.model_claim,
        "model_chat":  c.model_chat,
        "temperature": c.temperature,
        "max_tokens":  c.max_tokens,
        "updated_at":  c.updated_at.isoformat() if c.updated_at else None,
    }


@router.get("")
async def get_config(
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    cfg = db.query(LLMConfig).first()
    if not cfg:
        raise HTTPException(404, "Config not initialized")
    return _config_dict(cfg)


class UpdateConfigRequest(BaseModel):
    provider: Optional[str] = None
    model_summ: Optional[str] = None
    model_ner: Optional[str] = None
    model_sent: Optional[str] = None
    model_claim: Optional[str] = None
    model_chat: Optional[str] = None
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None


VALID_PROVIDERS = {"Groq", "OpenAI", "Anthropic"}


@router.put("")
async def update_config(
    req: UpdateConfigRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    cfg = db.query(LLMConfig).first()
    if not cfg:
        raise HTTPException(404, "Config not initialized")

    if req.provider is not None:
        if req.provider not in VALID_PROVIDERS:
            raise HTTPException(400, f"provider must be one of: {', '.join(VALID_PROVIDERS)}")
        cfg.provider = req.provider
    if req.model_summ  is not None: cfg.model_summ  = req.model_summ
    if req.model_ner   is not None: cfg.model_ner   = req.model_ner
    if req.model_sent  is not None: cfg.model_sent  = req.model_sent
    if req.model_claim is not None: cfg.model_claim = req.model_claim
    if req.model_chat  is not None: cfg.model_chat  = req.model_chat
    if req.temperature is not None:
        if not (0.0 <= req.temperature <= 2.0):
            raise HTTPException(400, "temperature must be 0.0–2.0")
        cfg.temperature = req.temperature
    if req.max_tokens is not None:
        if req.max_tokens < 128:
            raise HTTPException(400, "max_tokens must be ≥ 128")
        cfg.max_tokens = req.max_tokens

    db.add(AuditLog(
        user_id=admin.id, action="LLM_CONFIG_UPDATED",
        target_type="config", target_id="llm-config",
        details=f"Updated by {admin.email}",
    ))
    db.commit()
    return _config_dict(cfg)
