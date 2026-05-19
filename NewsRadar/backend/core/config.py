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

    # JWT
    JWT_SECRET: str = os.getenv("JWT_SECRET", "change-me-in-production")
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = int(os.getenv("JWT_EXPIRE_MINUTES", "10080"))

    # Email Configuration
    SENDGRID_API_KEY: str = os.getenv("SENDGRID_API_KEY", "")
    SENDGRID_FROM_EMAIL: str = os.getenv("SENDGRID_FROM_EMAIL", "noreply@newsradar.com")
    SENDGRID_FROM_NAME: str = os.getenv("SENDGRID_FROM_NAME", "NewsRadar")

    # SMTP Configuration (Fallback)
    SMTP_HOST: str = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER: str = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")

    # App Settings
    APP_URL: str = os.getenv("APP_URL", "http://localhost:3000")
    ADMIN_EMAIL: str = os.getenv("ADMIN_EMAIL", "admin@newsradar.com")
    DEFAULT_INVITE_EXPIRES_HOURS: int = int(os.getenv("DEFAULT_INVITE_EXPIRES_HOURS", "72"))
    DEFAULT_PASSWORD_RESET_EXPIRES_MINUTES: int = int(os.getenv("DEFAULT_PASSWORD_RESET_EXPIRES_MINUTES", "60"))

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

    # MFA
    MFA_ISSUER: str = "NewsRadar"
    MFA_ENABLED_BY_DEFAULT: bool = False


settings = Settings()
