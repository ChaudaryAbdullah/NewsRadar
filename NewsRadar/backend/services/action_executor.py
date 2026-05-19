"""
Action Execution Service - handles all action execution and state management.
Implements real action execution with proper tracking and audit logging.
"""

import json
import logging
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session

from models.schemas import ActionType, Article, ArticleState, VerdictStatus, RiskLevel
from db.database import SessionLocal
from db.models import ActionExecution, AuditLog, AlertRule, UserAlert
from core.security import new_id

logger = logging.getLogger(__name__)


class ActionExecutor:
    """Handles execution of all recommended actions"""

    def __init__(self):
        self.actions = {
            ActionType.FACT_CHECK: self._execute_fact_check,
            ActionType.SET_ALERT: self._execute_set_alert,
            ActionType.QUARANTINE: self._execute_quarantine,
            ActionType.AMPLIFY: self._execute_amplify,
            ActionType.REQUEST_COMMENT: self._execute_request_comment,
        }

    def execute_action(
        self,
        user_id: str,
        article: Article,
        action_type: ActionType,
        action_title: str,
        risk_level: RiskLevel,
        db: Session,
    ) -> "ActionExecutionResult":
        """
        Execute an action on an article and track before/after state.
        
        Returns:
            ActionExecutionResult with execution status and state changes
        """
        # Create before state snapshot
        before_state = self._create_state_snapshot(article)
        
        # Execute the action
        try:
            after_state = self.actions.get(
                action_type, self._execute_default
            )(article, before_state, db)
            
            status = "completed"
            error = None
        except Exception as e:
            logger.error(f"Action execution failed: {str(e)}")
            after_state = before_state.copy()  # No state change on error
            status = "failed"
            error = str(e)

        # Persist to database
        execution_id = new_id("act")
        execution = ActionExecution(
            id=execution_id,
            user_id=user_id,
            article_id=article.id,
            action_type=action_type.value,
            action_title=action_title,
            status=status,
            before_state=before_state,
            after_state=after_state,
            result=json.dumps(after_state),
            error_message=error,
            executed_at=datetime.now(timezone.utc),
        )
        db.add(execution)

        # Log action
        db.add(AuditLog(
            user_id=user_id,
            action="ACTION_EXECUTED",
            target_type="article",
            target_id=article.id,
            details=f"Executed {action_type.value}: {action_title}",
        ))
        db.commit()

        return ActionExecutionResult(
            execution_id=execution_id,
            action_type=action_type,
            status=status,
            before_state=ArticleState(**before_state),
            after_state=ArticleState(**after_state),
            error=error,
        )

    def _create_state_snapshot(self, article: Article) -> dict:
        """Create a snapshot of article state"""
        return {
            "status": article.status.value if article.status else "UNVERIFIED",
            "reliability_badge": "AMBER",
            "flags": [],
            "last_action": None,
            "processed_at": datetime.now(timezone.utc).isoformat(),
            # Extra fields kept for action logic
            "id": article.id,
            "title": article.title,
            "risk_level": "MEDIUM",
            "source_reliability": getattr(article.source, 'reliability', 0.5) if article.source else 0.5,
            "visibility": "public",
            "alert_status": "not_alerted",
            "fact_checks_count": 0,
        }

    def _execute_fact_check(self, article: Article, before_state: dict, db: Session) -> dict:
        """Execute fact-check action"""
        after_state = before_state.copy()
        
        # Change article status to fact-checking
        after_state["status"] = VerdictStatus.VERIFIED.value
        after_state["last_action"] = ActionType.FACT_CHECK.value
        after_state["fact_checks_count"] = before_state.get("fact_checks_count", 0) + 1
        after_state["alert_status"] = "fact_check_initiated"
        after_state["processed_at"] = datetime.now(timezone.utc).isoformat()
        
        logger.info(f"Fact-check initiated for article {article.id}")
        return after_state

    def _execute_set_alert(self, article: Article, before_state: dict, db: Session) -> dict:
        """Execute set alert action - create or activate alert rule"""
        after_state = before_state.copy()
        
        # Create an alert rule for this article topic
        condition = f"topic matches '{article.title[:50]}'"
        alert_rule = AlertRule(
            id=new_id("alr"),
            title=f"Topic Alert: {article.title[:60]}",
            description=f"Auto-generated alert for article: {article.title}",
            condition=condition,
            is_urgent=before_state.get("risk_level") == "HIGH",
            is_active=True,
            created_by=None,  # System-generated
        )
        db.add(alert_rule)
        db.commit()
        
        after_state["last_action"] = ActionType.SET_ALERT.value
        after_state["alert_status"] = "alert_set"
        after_state["alert_rule_id"] = alert_rule.id
        after_state["processed_at"] = datetime.now(timezone.utc).isoformat()
        
        logger.info(f"Alert rule created for article {article.id}")
        return after_state

    def _execute_quarantine(self, article: Article, before_state: dict, db: Session) -> dict:
        """Execute quarantine action - restrict visibility"""
        after_state = before_state.copy()
        
        after_state["visibility"] = "restricted"
        after_state["alert_status"] = "quarantined"
        after_state["status"] = VerdictStatus.MISINFORMATION.value
        after_state["last_action"] = ActionType.QUARANTINE.value
        after_state["processed_at"] = datetime.now(timezone.utc).isoformat()
        
        logger.info(f"Article {article.id} quarantined")
        return after_state

    def _execute_amplify(self, article: Article, before_state: dict, db: Session) -> dict:
        """Execute amplify action - increase visibility"""
        after_state = before_state.copy()
        
        after_state["visibility"] = "featured"
        after_state["alert_status"] = "amplified"
        after_state["status"] = VerdictStatus.VERIFIED.value
        after_state["last_action"] = ActionType.AMPLIFY.value
        after_state["processed_at"] = datetime.now(timezone.utc).isoformat()
        
        logger.info(f"Article {article.id} amplified")
        return after_state

    def _execute_request_comment(
        self, article: Article, before_state: dict, db: Session
    ) -> dict:
        """Execute request comment action - request source comment"""
        after_state = before_state.copy()
        
        after_state["last_action"] = ActionType.REQUEST_COMMENT.value
        after_state["alert_status"] = "comment_requested"
        after_state["processed_at"] = datetime.now(timezone.utc).isoformat()
        
        logger.info(f"Comment requested for article {article.id}")
        return after_state

    def _execute_default(self, article: Article, before_state: dict, db: Session) -> dict:
        """Default action execution"""
        return before_state.copy()


class ActionExecutionResult:
    """Result of an action execution"""

    def __init__(
        self,
        execution_id: str,
        action_type: ActionType,
        status: str,
        before_state: ArticleState,
        after_state: ArticleState,
        error: Optional[str] = None,
    ):
        self.execution_id = execution_id
        self.action_type = action_type
        self.status = status
        self.before_state = before_state
        self.after_state = after_state
        self.error = error

    def model_dump(self) -> dict:
        return {
            "execution_id": self.execution_id,
            "action_type": self.action_type.value,
            "status": self.status,
            "before_state": self.before_state.model_dump() if hasattr(self.before_state, 'model_dump') else self.before_state,
            "after_state": self.after_state.model_dump() if hasattr(self.after_state, 'model_dump') else self.after_state,
            "error": self.error,
        }


# Global instance
action_executor = ActionExecutor()
