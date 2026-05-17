"""
NewsRadar FastAPI application entry point.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.articles import router as articles_router
from api.analysis import router as analysis_router
from api.health import router as health_router
from core.config import settings

app = FastAPI(
    title="NewsRadar API",
    description="AI-powered news intelligence — Google Antigravity Hackathon",
    version="1.0.0",
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

# Routers
app.include_router(health_router)
app.include_router(articles_router)
app.include_router(analysis_router)


@app.get("/")
async def root():
    return {
        "app": "NewsRadar",
        "tagline": "AI-powered news intelligence",
        "docs": "/docs",
        "health": "/api/v1/health",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
