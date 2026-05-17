"""
Health check router.
GET /api/v1/health — liveness probe
"""

from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter(prefix="/api/v1", tags=["Health"])


@router.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "NewsRadar API",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
