"""
Database seeding - Production mode: only create minimal default data on first run.
Never overwrite existing data. Admins should manage data through UI/API.
"""

import logging
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from core.security import hash_password

from .models import User, Source, AlertRule, LLMConfig, AuditLog, SystemConfig

logger = logging.getLogger(__name__)


def seed_db(db: Session):
    """
    Seed database with minimal default data only on first run.
    Idempotent - checks before inserting to avoid duplicates.
    """
    
    # Only seed if all tables are empty
    user_count = db.query(User).count()
    source_count = db.query(Source).count()
    
    if user_count > 0 and source_count > 0:
        logger.info("Database already seeded, skipping initialization")
        return
    
    # Create admin user if no users exist
    if user_count == 0:
        logger.info("Creating default admin user...")
        admin = User(
            id="usr-admin",
            name="Administrator",
            email="admin@newsradar.com",
            hashed_pw=hash_password("Admin@123456"),  # MUST BE CHANGED IN PRODUCTION
            role="admin",
            status="active",
            email_verified=True,
        )
        db.add(admin)
        db.add(AuditLog(
            user_id=admin.id,
            action="SYSTEM_INITIALIZATION",
            target_type="user",
            target_id=admin.id,
            details="Default admin user created during database initialization",
        ))
        logger.info("✓ Default admin user created: admin@newsradar.com / Admin@123456")
    
    # Create default news sources if none exist
    if source_count == 0:
        logger.info("Creating default news sources...")
        default_sources = [
            Source(
                id="src-bbc",
                name="BBC News",
                url="https://feeds.bbc.co.uk/news/rss.xml",
                source_type="RSS",
                reliability=0.92,
                is_active=True,
            ),
            Source(
                id="src-reuters",
                name="Reuters",
                url="https://www.reuters.com/",
                source_type="API",
                reliability=0.94,
                is_active=True,
            ),
            Source(
                id="src-ap",
                name="AP News",
                url="https://apnews.com/",
                source_type="SCRAPER",
                reliability=0.90,
                is_active=True,
            ),
        ]
        for src in default_sources:
            db.add(src)
        db.add(AuditLog(
            action="SYSTEM_INITIALIZATION",
            target_type="source",
            details=f"Created {len(default_sources)} default news sources",
        ))
        logger.info(f"✓ Created {len(default_sources)} default news sources")
    
    # Create LLM config if not exists
    if db.query(LLMConfig).count() == 0:
        logger.info("Creating LLM configuration...")
        llm_config = LLMConfig(
            provider="Groq",
            model_summ="llama-3.3-70b-versatile",
            model_ner="llama-3.1-8b-instant",
            model_sent="llama-3.1-8b-instant",
            model_claim="llama-3.3-70b-versatile",
            model_chat="llama-3.3-70b-versatile",
            temperature=0.3,
            max_tokens=2048,
        )
        db.add(llm_config)
        logger.info("✓ LLM configuration created")
    
    # Create system config defaults
    if db.query(SystemConfig).count() == 0:
        logger.info("Creating system configuration...")
        system_configs = [
            SystemConfig(
                id="config-app-name",
                key="app_name",
                value="NewsRadar",
                description="Application name",
                config_type="string",
            ),
            SystemConfig(
                id="config-app-version",
                key="app_version",
                value="2.0.0",
                description="Application version",
                config_type="string",
            ),
            SystemConfig(
                id="config-feature-mfa",
                key="feature_mfa_enabled",
                value="true",
                description="Enable two-factor authentication",
                config_type="boolean",
            ),
            SystemConfig(
                id="config-feature-alerts",
                key="feature_alerts_enabled",
                value="true",
                description="Enable alert notifications",
                config_type="boolean",
            ),
            SystemConfig(
                id="config-max-users",
                key="max_users",
                value="-1",
                description="Maximum users allowed (-1 = unlimited)",
                config_type="number",
            ),
        ]
        for config in system_configs:
            db.add(config)
        logger.info(f"✓ Created {len(system_configs)} system configuration entries")
    
    db.commit()
    logger.info("✓ Database seeding completed successfully")
    logger.warning("⚠️  IMPORTANT: Change the default admin password immediately in production!")
