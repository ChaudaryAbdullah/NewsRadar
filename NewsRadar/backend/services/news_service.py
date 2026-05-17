"""
NewsAPI integration — all news fetching lives here.
"""

import hashlib
import re
import httpx
from typing import List, Optional
from models.schemas import Article, ArticleSource, VerdictStatus
from core.config import settings

NEWS_API_BASE = settings.NEWS_API_BASE
NEWS_API_KEY = settings.NEWSAPI_KEY

CATEGORIES = [
    "business", "entertainment", "general",
    "health", "science", "sports", "technology",
]


def _make_id(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()[:16]


def _parse_raw(raw: dict) -> Optional[Article]:
    title = raw.get("title", "")
    if not title or title == "[Removed]":
        return None
    src = raw.get("source", {})
    return Article(
        id=_make_id(raw.get("url") or title),
        title=title,
        description=raw.get("description"),
        content=raw.get("content"),
        url=raw.get("url", ""),
        urlToImage=raw.get("urlToImage"),
        publishedAt=raw.get("publishedAt", ""),
        source=ArticleSource(id=src.get("id"), name=src.get("name", "Unknown")),
        author=raw.get("author"),
        status=VerdictStatus.UNVERIFIED,
    )


async def fetch_top_headlines(
    category: Optional[str] = None,
    q: Optional[str] = None,
    page_size: int = 20,
    page: int = 1,
) -> List[Article]:
    params = {
        "apiKey": NEWS_API_KEY,
        "language": "en",
        "pageSize": min(page_size, 100),
        "page": page,
        "country": "us",
    }
    if category and category in CATEGORIES:
        params["category"] = category
    if q:
        params["q"] = q
    # country + sources conflict, so drop country if category is set
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(f"{NEWS_API_BASE}/top-headlines", params=params)
        resp.raise_for_status()
        data = resp.json()
    return [a for raw in data.get("articles", []) if (a := _parse_raw(raw))]


async def search_news(query: str, page_size: int = 20, page: int = 1) -> List[Article]:
    params = {
        "apiKey": NEWS_API_KEY,
        "q": query,
        "language": "en",
        "sortBy": "publishedAt",
        "pageSize": min(page_size, 100),
        "page": page,
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(f"{NEWS_API_BASE}/everything", params=params)
        resp.raise_for_status()
        data = resp.json()
    return [a for raw in data.get("articles", []) if (a := _parse_raw(raw))]


async def fetch_article_body(url: str) -> Optional[str]:
    """Best-effort full text fetch from the article URL."""
    try:
        async with httpx.AsyncClient(
            timeout=10.0,
            follow_redirects=True,
            headers={"User-Agent": "NewsRadar/1.0 (Hackathon)"},
        ) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                text = re.sub(r"<[^>]+>", " ", resp.text)
                text = re.sub(r"\s+", " ", text).strip()
                return text[:4000]
    except Exception:
        pass
    return None
