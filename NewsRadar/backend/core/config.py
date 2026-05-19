import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    # API Keys
    NEWSAPI_KEY: str = os.getenv("NEWSAPI_KEY", "")
    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")

    # Server
    PORT: int = int(os.getenv("PORT", "8000"))
    HOST: str = os.getenv("HOST", "0.0.0.0")
    DEBUG: bool = os.getenv("DEBUG", "true").lower() == "true"

    # CORS — allow all for hackathon demo
    ALLOWED_ORIGINS: list = ["*"]

    # NewsAPI
    NEWS_API_BASE: str = "https://newsapi.org/v2"
    NEWS_PAGE_SIZE: int = 20

    # Groq
    GROQ_MODEL: str = "llama-3.1-8b-instant"
    GROQ_TEMPERATURE: float = 0.3
    GROQ_MAX_TOKENS: int = 2048

    # Source reliability known scores (used in evaluation)
    KNOWN_RELIABLE_SOURCES: dict = {
        "bbc-news": 0.95,
        "reuters": 0.95,
        "associated-press": 0.94,
        "the-guardian-uk": 0.88,
        "nbc-news": 0.82,
        "cnn": 0.78,
        "the-washington-post": 0.85,
        "the-new-york-times": 0.87,
        "al-jazeera-english": 0.80,
        "techcrunch": 0.82,
        "wired": 0.83,
        "the-verge": 0.80,
    }

    DEFAULT_RELIABILITY: float = 0.55


settings = Settings()
