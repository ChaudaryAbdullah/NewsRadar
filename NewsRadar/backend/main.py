"""
NewsRadar FastAPI application entry point.
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse

from api.articles    import router as articles_router
from api.analysis    import router as analysis_router
from api.health      import router as health_router
from api.chat        import router as chat_router
from api.auth        import router as auth_router
from api.admin_users import router as admin_users_router
from api.admin_sources import router as admin_sources_router
from api.admin_llm   import router as admin_llm_router
from api.alerts      import router as alerts_router
from api.audit       import router as audit_router

from core.config import settings
from db.database import engine, SessionLocal
from db.models   import Base
from db.seed     import seed_db

# ── Create DB tables and seed demo data ───────────────────────────────────────
Base.metadata.create_all(bind=engine)
with SessionLocal() as db:
    seed_db(db)

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="NewsRadar API",
    description="AI-powered news intelligence — Google Antigravity Hackathon",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — allow Flutter app (any origin for hackathon)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(articles_router)
app.include_router(analysis_router)
app.include_router(chat_router)
app.include_router(admin_users_router)
app.include_router(admin_sources_router)
app.include_router(admin_llm_router)
app.include_router(alerts_router)
app.include_router(audit_router)

# ── Static frontend (optional) ────────────────────────────────────────────────
frontend_path = os.path.join(os.path.dirname(__file__), "..", "frontend_web")
if os.path.exists(frontend_path):
    app.mount("/app", StaticFiles(directory=frontend_path, html=True), name="frontend")

@app.get("/")
async def root():
    if os.path.exists(frontend_path):
        return RedirectResponse(url="/app/home_feed.html")
    return {
        "app": "NewsRadar",
        "tagline": "AI-powered news intelligence",
        "version": "2.0.0",
        "docs": "/docs",
        "health": "/api/v1/health",
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
