"""
SQLAlchemy ORM models for NewsRadar.
Production-ready with full tracking and audit support.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, Float, DateTime, Text, Integer, ForeignKey, JSON
from sqlalchemy.orm import relationship
from .database import Base


def _now():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id                  = Column(String, primary_key=True)
    name                = Column(String, nullable=False)
    email               = Column(String, unique=True, nullable=False, index=True)
    hashed_pw           = Column(String, nullable=False)
    role                = Column(String, nullable=False, default="consumer")
    status              = Column(String, nullable=False, default="pending")   # pending | active | locked | archived
    email_verified      = Column(Boolean, default=False)
    email_verify_token  = Column(String, nullable=True)
    mfa_enabled         = Column(Boolean, default=False)
    mfa_secret          = Column(String, nullable=True)
    password_reset_token = Column(String, nullable=True)
    password_reset_expires = Column(DateTime, nullable=True)
    last_login          = Column(DateTime, nullable=True)
    preferences         = Column(JSON, default={})  # User preferences (themes, notifications, etc.)
    created_at          = Column(DateTime, default=_now)
    updated_at          = Column(DateTime, default=_now, onupdate=_now)

    audit_logs          = relationship("AuditLog", back_populates="user", cascade="all, delete")
    invitations_sent    = relationship("UserInvitation", back_populates="invited_by", foreign_keys="UserInvitation.invited_by_id", cascade="all, delete")
    action_executions   = relationship("ActionExecution", back_populates="user", cascade="all, delete")
    chat_messages       = relationship("ChatMessage", back_populates="user", cascade="all, delete")
    alerts              = relationship("UserAlert", back_populates="user", cascade="all, delete")


class Source(Base):
    __tablename__ = "sources"

    id          = Column(String, primary_key=True)
    name        = Column(String, nullable=False)
    url         = Column(String, nullable=False)
    source_type = Column(String, nullable=False, default="RSS")   # RSS | API | SCRAPER
    reliability = Column(Float, default=0.75)
    is_active   = Column(Boolean, default=True)
    created_at  = Column(DateTime, default=_now)


class AlertRule(Base):
    __tablename__ = "alert_rules"

    id          = Column(String, primary_key=True)
    title       = Column(String, nullable=False)
    description = Column(String, nullable=False)
    condition   = Column(String, nullable=False)   # e.g. "misinformation_pct > 30"
    is_urgent   = Column(Boolean, default=False)
    is_active   = Column(Boolean, default=True)
    created_by  = Column(String, ForeignKey("users.id"), nullable=True)
    created_at  = Column(DateTime, default=_now)


class LLMConfig(Base):
    __tablename__ = "llm_config"

    id          = Column(Integer, primary_key=True, autoincrement=True)
    provider    = Column(String, default="Groq")
    model_summ  = Column(String, default="llama-3.3-70b-versatile")
    model_ner   = Column(String, default="llama-3.1-8b-instant")
    model_sent  = Column(String, default="llama-3.1-8b-instant")
    model_claim = Column(String, default="llama-3.3-70b-versatile")
    model_chat  = Column(String, default="llama-3.3-70b-versatile")
    temperature = Column(Float, default=0.3)
    max_tokens  = Column(Integer, default=2048)
    updated_at  = Column(DateTime, default=_now, onupdate=_now)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id          = Column(Integer, primary_key=True, autoincrement=True)
    user_id     = Column(String, ForeignKey("users.id"), nullable=True)
    action      = Column(String, nullable=False)
    target_type = Column(String, nullable=True)   # "article" | "user" | "source" | "config"
    target_id   = Column(String, nullable=True)
    details     = Column(Text, nullable=True)
    created_at  = Column(DateTime, default=_now)

    user = relationship("User", back_populates="audit_logs")


class UserInvitation(Base):
    """Track user invitations and their status"""
    __tablename__ = "user_invitations"

    id              = Column(String, primary_key=True)
    invited_by_id   = Column(String, ForeignKey("users.id"), nullable=False)
    email           = Column(String, nullable=False)
    full_name       = Column(String, nullable=False)
    role            = Column(String, nullable=False, default="consumer")
    status          = Column(String, default="pending")  # pending | accepted | expired | cancelled
    invitation_token = Column(String, unique=True, nullable=False)
    accepted_at     = Column(DateTime, nullable=True)
    expires_at      = Column(DateTime, nullable=False)
    created_at      = Column(DateTime, default=_now)

    invited_by = relationship("User", back_populates="invitations_sent", foreign_keys=[invited_by_id])


class ActionExecution(Base):
    """Track all action executions with before/after states"""
    __tablename__ = "action_executions"

    id              = Column(String, primary_key=True)
    user_id         = Column(String, ForeignKey("users.id"), nullable=False)
    article_id      = Column(String, nullable=False)  # Original article ID
    action_type     = Column(String, nullable=False)  # FACT_CHECK | SET_ALERT | etc
    action_title    = Column(String, nullable=False)
    status          = Column(String, default="pending")  # pending | in_progress | completed | failed
    before_state    = Column(JSON, nullable=False)  # Snapshot of article state before action
    after_state     = Column(JSON, nullable=True)   # Snapshot of article state after action
    result          = Column(Text, nullable=True)   # Execution result/output
    error_message   = Column(Text, nullable=True)   # If failed, error details
    executed_at     = Column(DateTime, nullable=True)
    created_at      = Column(DateTime, default=_now)

    user = relationship("User", back_populates="action_executions")


class ChatMessage(Base):
    """Persist chat conversation history per user"""
    __tablename__ = "chat_messages"

    id              = Column(String, primary_key=True)
    user_id         = Column(String, ForeignKey("users.id"), nullable=False)
    session_id      = Column(String, nullable=False)  # Group messages by session
    role            = Column(String, nullable=False)  # "user" | "assistant"
    content         = Column(Text, nullable=False)
    article_context = Column(JSON, nullable=True)     # Optional article context
    sources         = Column(JSON, nullable=True)     # Citations/sources
    created_at      = Column(DateTime, default=_now)

    user = relationship("User", back_populates="chat_messages")


class UserAlert(Base):
    """User subscriptions to alert rules"""
    __tablename__ = "user_alerts"

    id              = Column(String, primary_key=True)
    user_id         = Column(String, ForeignKey("users.id"), nullable=False)
    alert_rule_id   = Column(String, ForeignKey("alert_rules.id"), nullable=False)
    is_active       = Column(Boolean, default=True)
    delivery_method = Column(String, default="in_app")  # in_app | email | webhook
    created_at      = Column(DateTime, default=_now)

    user = relationship("User", back_populates="alerts")
    alert_rule = relationship("AlertRule")


class AgentTraceDB(Base):
    """Persist agent execution traces in database instead of disk"""
    __tablename__ = "agent_traces"

    id              = Column(String, primary_key=True)
    user_id         = Column(String, ForeignKey("users.id"), nullable=True)
    article_id      = Column(String, nullable=False)
    trace_data      = Column(JSON, nullable=False)  # Full trace object
    duration_ms     = Column(Integer, nullable=True)
    status          = Column(String, default="completed")  # completed | failed
    created_at      = Column(DateTime, default=_now)


class EmailLog(Base):
    """Track all sent emails for debugging and compliance"""
    __tablename__ = "email_logs"

    id              = Column(String, primary_key=True)
    recipient       = Column(String, nullable=False)
    subject         = Column(String, nullable=False)
    email_type      = Column(String, nullable=False)  # verification | reset | invitation | alert
    status          = Column(String, default="sent")   # sent | failed | bounced
    error_message   = Column(Text, nullable=True)
    sent_at         = Column(DateTime, default=_now)


class SystemConfig(Base):
    """Dynamic system configuration (replaces hardcoded values)"""
    __tablename__ = "system_config"

    id              = Column(String, primary_key=True)
    key             = Column(String, unique=True, nullable=False)
    value           = Column(Text, nullable=False)
    description     = Column(String, nullable=True)
    config_type     = Column(String, default="string")  # string | number | boolean | json
    updated_at      = Column(DateTime, default=_now, onupdate=_now)

