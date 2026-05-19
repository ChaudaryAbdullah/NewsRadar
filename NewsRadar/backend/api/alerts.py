"""
Alert Rules API (Production-ready)
GET    /api/v1/alerts              — list all alert rules
POST   /api/v1/alerts              — create a new rule (editor+)
PATCH  /api/v1/alerts/{id}         — update rule (editor+)
DELETE /api/v1/alerts/{id}         — delete rule (admin only)
POST   /api/v1/alerts/{id}/subscribe — subscribe to alert
DELETE /api/v1/alerts/{id}/subscribe — unsubscribe from alert
"""

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import AlertRule, AuditLog, User, UserAlert
from core.security import new_id
from core.deps import get_current_user, require_editor, require_admin

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/alerts", tags=["Alert Rules"])


def _rule_dict(r: AlertRule, subscribed: bool = False) -> dict:
    return {
        "id": r.id,
        "title": r.title,
        "description": r.description,
        "condition": r.condition,
        "is_urgent": r.is_urgent,
        "is_active": r.is_active,
        "created_by": r.created_by,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "subscribed": subscribed,
    }


# ── List Alert Rules ──────────────────────────────────────────────────────────

@router.get("")
async def list_alerts(
    include_inactive: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all alert rules (with user subscription status)"""
    
    query = db.query(AlertRule)
    if not include_inactive:
        query = query.filter(AlertRule.is_active == True)
    
    rules = query.order_by(AlertRule.created_at.desc()).all()
    
    # Get user's subscriptions
    user_subscriptions = db.query(UserAlert).filter(
        UserAlert.user_id == current_user.id,
        UserAlert.is_active == True
    ).all()
    subscribed_rule_ids = {sub.alert_rule_id for sub in user_subscriptions}
    
    return {
        "alerts": [_rule_dict(r, r.id in subscribed_rule_ids) for r in rules],
        "total": len(rules),
    }


# ── Create Alert Rule ─────────────────────────────────────────────────────────

class CreateAlertRequest(BaseModel):
    title: str
    description: str
    condition: str  # e.g., "misinformation_pct > 30" or "topic contains 'AI'"
    is_urgent: bool = False
    is_active: bool = True


@router.post("", status_code=201)
async def create_alert(
    req: CreateAlertRequest,
    editor: User = Depends(require_editor),
    db: Session = Depends(get_db),
):
    """Create a new alert rule (requires editor role)"""
    
    # Validate inputs
    if len(req.title.strip()) < 3:
        raise HTTPException(400, "Title must be at least 3 characters")
    if len(req.description.strip()) < 10:
        raise HTTPException(400, "Description must be at least 10 characters")
    if len(req.condition.strip()) < 5:
        raise HTTPException(400, "Condition must be at least 5 characters")
    
    rule = AlertRule(
        id=new_id("alr"),
        title=req.title.strip(),
        description=req.description.strip(),
        condition=req.condition.strip(),
        is_urgent=req.is_urgent,
        is_active=req.is_active,
        created_by=editor.id,
    )
    db.add(rule)
    
    db.add(AuditLog(
        user_id=editor.id,
        action="ALERT_RULE_CREATED",
        target_type="alert_rule",
        target_id=rule.id,
        details=f"Alert rule created: {req.title}",
    ))
    db.commit()
    db.refresh(rule)
    
    logger.info(f"Alert rule created by {editor.email}: {rule.title}")
    return _rule_dict(rule)


# ── Update Alert Rule ────────────────────────────────────────────────────────

class UpdateAlertRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    condition: Optional[str] = None
    is_urgent: Optional[bool] = None
    is_active: Optional[bool] = None


@router.patch("/{alert_id}")
async def update_alert(
    alert_id: str,
    req: UpdateAlertRequest,
    editor: User = Depends(require_editor),
    db: Session = Depends(get_db),
):
    """Update an alert rule (requires editor role)"""
    
    rule = db.query(AlertRule).filter(AlertRule.id == alert_id).first()
    if not rule:
        raise HTTPException(404, "Alert rule not found")
    
    # Only admin or creator can edit
    if editor.role != "admin" and rule.created_by != editor.id:
        raise HTTPException(403, "You can only edit rules you created")
    
    changes = []
    
    if req.title is not None:
        if len(req.title.strip()) < 3:
            raise HTTPException(400, "Title must be at least 3 characters")
        if req.title != rule.title:
            changes.append(f"title: {rule.title} → {req.title}")
        rule.title = req.title.strip()
    
    if req.description is not None:
        if len(req.description.strip()) < 10:
            raise HTTPException(400, "Description must be at least 10 characters")
        if req.description != rule.description:
            changes.append(f"description updated")
        rule.description = req.description.strip()
    
    if req.condition is not None:
        if len(req.condition.strip()) < 5:
            raise HTTPException(400, "Condition must be at least 5 characters")
        if req.condition != rule.condition:
            changes.append(f"condition: {rule.condition} → {req.condition}")
        rule.condition = req.condition.strip()
    
    if req.is_urgent is not None and req.is_urgent != rule.is_urgent:
        changes.append(f"urgent: {rule.is_urgent} → {req.is_urgent}")
        rule.is_urgent = req.is_urgent
    
    if req.is_active is not None and req.is_active != rule.is_active:
        changes.append(f"active: {rule.is_active} → {req.is_active}")
        rule.is_active = req.is_active
    
    if changes:
        db.add(AuditLog(
            user_id=editor.id,
            action="ALERT_RULE_UPDATED",
            target_type="alert_rule",
            target_id=rule.id,
            details=f"Changes: {', '.join(changes)}",
        ))
        db.commit()
        logger.info(f"Alert rule updated by {editor.email}: {rule.title}")
    
    return _rule_dict(rule)


# ── Delete Alert Rule ────────────────────────────────────────────────────────

@router.delete("/{alert_id}", status_code=204)
async def delete_alert(
    alert_id: str,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Delete an alert rule (admin only)"""
    
    rule = db.query(AlertRule).filter(AlertRule.id == alert_id).first()
    if not rule:
        raise HTTPException(404, "Alert rule not found")
    
    # Delete all subscriptions to this rule
    db.query(UserAlert).filter(UserAlert.alert_rule_id == alert_id).delete()
    
    db.add(AuditLog(
        user_id=admin.id,
        action="ALERT_RULE_DELETED",
        target_type="alert_rule",
        target_id=rule.id,
        details=f"Alert rule deleted: {rule.title}",
    ))
    db.delete(rule)
    db.commit()
    
    logger.info(f"Alert rule deleted by {admin.email}: {rule.title}")


# ── Subscribe to Alert ────────────────────────────────────────────────────────

class SubscribeRequest(BaseModel):
    delivery_method: str = "in_app"  # in_app | email | webhook


@router.post("/{alert_id}/subscribe", status_code=201)
async def subscribe_alert(
    alert_id: str,
    req: SubscribeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Subscribe to an alert rule"""
    
    rule = db.query(AlertRule).filter(AlertRule.id == alert_id).first()
    if not rule:
        raise HTTPException(404, "Alert rule not found")
    
    if req.delivery_method not in ("in_app", "email", "webhook"):
        raise HTTPException(400, "delivery_method must be 'in_app', 'email', or 'webhook'")
    
    # Check if already subscribed
    existing = db.query(UserAlert).filter(
        UserAlert.user_id == current_user.id,
        UserAlert.alert_rule_id == alert_id,
    ).first()
    
    if existing:
        # Reactivate if was unsubscribed
        existing.is_active = True
        existing.delivery_method = req.delivery_method
        db.commit()
    else:
        subscription = UserAlert(
            id=new_id("usralr"),
            user_id=current_user.id,
            alert_rule_id=alert_id,
            is_active=True,
            delivery_method=req.delivery_method,
        )
        db.add(subscription)
        db.add(AuditLog(
            user_id=current_user.id,
            action="ALERT_SUBSCRIBED",
            target_type="user_alert",
            target_id=subscription.id,
            details=f"Subscribed to: {rule.title}",
        ))
        db.commit()
    
    logger.info(f"User {current_user.email} subscribed to alert: {rule.title}")
    return {"message": "Subscribed to alert successfully"}


# ── Unsubscribe from Alert ───────────────────────────────────────────────────

@router.delete("/{alert_id}/subscribe", status_code=204)
async def unsubscribe_alert(
    alert_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Unsubscribe from an alert rule"""
    
    subscription = db.query(UserAlert).filter(
        UserAlert.user_id == current_user.id,
        UserAlert.alert_rule_id == alert_id,
    ).first()
    
    if not subscription:
        raise HTTPException(404, "Subscription not found")
    
    subscription.is_active = False
    
    db.add(AuditLog(
        user_id=current_user.id,
        action="ALERT_UNSUBSCRIBED",
        target_type="user_alert",
        target_id=subscription.id,
        details="Unsubscribed from alert",
    ))
    db.commit()
    
    logger.info(f"User {current_user.email} unsubscribed from alert")
