"""
Analysis router — AI agent endpoints (Production-ready)
POST /api/v1/analysis/analyze         — run full agent pipeline on an article
POST /api/v1/analysis/execute-action  — actually execute an action (real tracking)
POST /api/v1/analysis/simulate        — simulate action (for demo/testing)
GET  /api/v1/analysis/traces          — list recent agent traces
GET  /api/v1/analysis/executions      — list action execution history (user's)
"""

import json
import os
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import AgentTraceDB, ActionExecution, User
from core.deps import get_current_user
from models.schemas import (
    Article,
    AnalysisResponse,
    SimulationResult,
    SimulateRequest,
    AgentTrace,
    ActionType,
)
from ai.agent import run_analysis, simulate_action
from services.action_executor import action_executor

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/analysis", tags=["Analysis"])

# In-memory trace store (keep for backwards compatibility, but also save to DB)
_trace_store: list[AgentTrace] = []
TRACE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "agent_traces")


def _save_trace(trace: AgentTrace, db: Optional[Session] = None, user_id: Optional[str] = None):
    """Persist trace to both memory and database."""
    _trace_store.append(trace)
    
    # Save to disk (for submission artifacts)
    try:
        os.makedirs(TRACE_DIR, exist_ok=True)
        path = os.path.join(TRACE_DIR, f"{trace.trace_id}.json")
        with open(path, "w") as f:
            json.dump(trace.model_dump(), f, indent=2)
    except Exception as e:
        logger.warning(f"Failed to save trace to disk: {e}")
    
    # Save to database
    if db and user_id:
        try:
            trace_db = AgentTraceDB(
                id=trace.trace_id,
                user_id=user_id,
                article_id=trace.steps[0].output_summary if trace.steps else "unknown",
                trace_data=trace.model_dump(),
                duration_ms=sum(step.duration_ms for step in trace.steps) if trace.steps else 0,
                status="completed",
            )
            db.add(trace_db)
            db.commit()
        except Exception as e:
            logger.error(f"Failed to save trace to database: {e}")


# ── Execute Action (Real) ─────────────────────────────────────────────────────

class ExecuteActionRequest(BaseModel):
    article_id: str
    article: Article
    action_type: ActionType
    action_title: str
    risk_level: str


@router.post("/execute-action", status_code=201)
async def execute_action(
    req: ExecuteActionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Actually execute an action on an article and track the execution.
    Returns real before/after state snapshots with full audit trail.
    """
    try:
        from models.schemas import RiskLevel
        
        # Execute the action with real state tracking
        result = action_executor.execute_action(
            user_id=current_user.id,
            article=req.article,
            action_type=req.action_type,
            action_title=req.action_title,
            risk_level=RiskLevel(req.risk_level),
            db=db,
        )
        
        logger.info(
            f"Action executed: {req.action_type.value} on {req.article_id} by {current_user.email}"
        )
        
        return result.model_dump()
        
    except Exception as e:
        logger.error(f"Action execution failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Action execution error: {str(e)}")


# ── Analyze Article ──────────────────────────────────────────────────────────

@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_article(
    article: Article,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Run the full 4-step NewsRadar agent pipeline on an article.
    Saves trace to database for audit trail.
    """
    try:
        result = await run_analysis(article)
        _save_trace(result.trace, db, current_user.id)
        return result
    except Exception as e:
        logger.error(f"Agent pipeline error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Agent pipeline error: {str(e)}")


# ── Simulate Action (Demo) ───────────────────────────────────────────────────

@router.post("/simulate", response_model=SimulationResult)
async def simulate_action_endpoint(req: SimulateRequest):
    """
    Simulate the execution of a recommended action (demo only).
    Returns simulated before/after state changes.
    This is for testing/demo purposes. Use /execute-action for real tracking.
    """
    try:
        result = simulate_action(req)
        return result
    except Exception as e:
        logger.error(f"Simulation error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Simulation error: {str(e)}")


# ── Get Traces ────────────────────────────────────────────────────────────────

@router.get("/traces")
async def get_traces(
    limit: int = 10,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get recent agent execution traces.
    Returns both in-memory traces and database traces.
    """
    # Get from database
    db_traces = db.query(AgentTraceDB).filter(
        AgentTraceDB.user_id == current_user.id
    ).order_by(
        AgentTraceDB.created_at.desc()
    ).limit(limit).all()
    
    traces = [t.trace_data for t in db_traces]
    
    return {
        "traces": traces,
        "total": len(traces),
        "user_id": current_user.id,
    }


# ── Get Action Executions ────────────────────────────────────────────────────

@router.get("/executions")
async def get_action_executions(
    skip: int = 0,
    limit: int = 50,
    status: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get user's action execution history.
    Shows all executed actions with before/after states.
    """
    query = db.query(ActionExecution).filter(
        ActionExecution.user_id == current_user.id
    )
    
    if status:
        query = query.filter(ActionExecution.status == status)
    
    executions = query.order_by(
        ActionExecution.created_at.desc()
    ).offset(skip).limit(limit).all()
    
    total = query.count()
    
    return {
        "executions": [
            {
                "id": e.id,
                "article_id": e.article_id,
                "action_type": e.action_type,
                "action_title": e.action_title,
                "status": e.status,
                "before_state": e.before_state,
                "after_state": e.after_state,
                "executed_at": e.executed_at.isoformat() if e.executed_at else None,
                "created_at": e.created_at.isoformat() if e.created_at else None,
            }
            for e in executions
        ],
        "total": total,
        "skip": skip,
        "limit": limit,
    }


# ── Get Action Execution Detail ───────────────────────────────────────────────

@router.get("/executions/{execution_id}")
async def get_execution_detail(
    execution_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get detailed information about a specific action execution."""
    execution = db.query(ActionExecution).filter(
        ActionExecution.id == execution_id,
        ActionExecution.user_id == current_user.id,
    ).first()
    
    if not execution:
        raise HTTPException(404, "Execution not found")
    
    return {
        "id": execution.id,
        "article_id": execution.article_id,
        "action_type": execution.action_type,
        "action_title": execution.action_title,
        "status": execution.status,
        "before_state": execution.before_state,
        "after_state": execution.after_state,
        "result": json.loads(execution.result) if execution.result else None,
        "error_message": execution.error_message,
        "executed_at": execution.executed_at.isoformat() if execution.executed_at else None,
        "created_at": execution.created_at.isoformat() if execution.created_at else None,
    }
