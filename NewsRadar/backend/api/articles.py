"""
Articles router — news feed endpoints.
GET /api/v1/articles           — top headlines (paginated, filterable)
GET /api/v1/articles/search    — full-text search
GET /api/v1/articles/categories — available categories
"""

from fastapi import APIRouter, Query, HTTPException
from typing import Optional
from models.schemas import ArticleListResponse, Article
from services.news_service import fetch_top_headlines, search_news, CATEGORIES

router = APIRouter(prefix="/api/v1/articles", tags=["Articles"])


@router.get("", response_model=ArticleListResponse)
async def get_articles(
    category: Optional[str] = Query(None, description="News category"),
    q: Optional[str] = Query(None, description="Keyword filter"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """Fetch top headlines with optional category/keyword filters."""
    try:
        articles = await fetch_top_headlines(
            category=category, q=q, page_size=page_size, page=page
        )
        return ArticleListResponse(
            articles=articles,
            total=len(articles),
            page=page,
            page_size=page_size,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"NewsAPI error: {str(e)}")


@router.get("/search", response_model=ArticleListResponse)
async def search_articles(
    q: str = Query(..., min_length=2, description="Search query"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """Search articles by keyword across all sources."""
    try:
        articles = await search_news(query=q, page_size=page_size, page=page)
        return ArticleListResponse(
            articles=articles,
            total=len(articles),
            page=page,
            page_size=page_size,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"NewsAPI error: {str(e)}")


@router.get("/categories")
async def get_categories():
    """Return available news categories."""
    return {"categories": CATEGORIES}
