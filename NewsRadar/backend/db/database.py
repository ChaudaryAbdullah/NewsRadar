"""
SQLAlchemy database setup.
Uses SQLite (in-memory or file-based via DATABASE_URL env var).
On Render free tier: file-based at /tmp/newsradar.db (ephemeral but stable within a session).
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:////tmp/newsradar.db")

# SQLite needs check_same_thread=False for multi-threaded use
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency — yields a DB session, always closes on exit."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
