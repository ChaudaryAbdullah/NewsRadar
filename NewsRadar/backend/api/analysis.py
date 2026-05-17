"""
Analysis router — AI agent endpoints.
POST /api/v1/analysis/analyze     — run full agent pipeline on an article
POST /api/v1/analysis/simulate    — simulate action execution (before/after)
GET  /api/v1/analysis/traces      — list recent agent traces (demo)
"""

import json
import os
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException
from models.schemas import (
    Article,
    AnalysisResponse,
    SimulationResult,
    SimulateRequest,
    AgentTrace,
)
from ai.agent import run_analysis, simulate_action

router = APIRouter(prefix="/api/v1/analysis", tags=["Analysis"])

# In-memory trace store (hackathon demo — replace with DB in production)
_trace_store: list[AgentTrace] = []
TRACE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "agent_traces")


def _save_trace(trace: AgentTrace):
    """Persist trace to disk as JSON for submission artifact."""
    _trace_store.append(trace)
    try:
        os.makedirs(TRACE_DIR, exist_ok=True)
        path = os.path.join(TRACE_DIR, f"{trace.trace_id}.json")
        with open(path, "w") as f:
            json.dump(trace.model_dump(), f, indent=2)
    except Exception:
        pass  # Non-critical


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_article(article: Article):
    """
    Run the full 4-step NewsRadar agent pipeline on an article.

    Pipeline: INGEST → EXTRACT_INSIGHTS → EVALUATE_IMPLICATIONS → GENERATE_ACTIONS
    Returns insights, evaluation, recommended actions, and agent trace.
    """
    try:
        result = await run_analysis(article)
        _save_trace(result.trace)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Agent pipeline error: {str(e)}")


@router.post("/simulate", response_model=SimulationResult)
async def simulate_action_endpoint(req: SimulateRequest):
    """
    Simulate the execution of a recommended action.
    Returns before/after article state — core Challenge 1 deliverable.
    """
    try:
        result = simulate_action(req)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Simulation error: {str(e)}")


@router.get("/traces")
async def get_traces(limit: int = 10):
    """Return recent agent execution traces (for demo/submission)."""
    traces = _trace_store[-limit:]
    return {
        "traces": [t.model_dump() for t in reversed(traces)],
        "total": len(_trace_store),
    }
