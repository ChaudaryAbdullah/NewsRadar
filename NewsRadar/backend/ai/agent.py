"""
NewsRadar Agent — the core AI pipeline.

Pipeline steps:
  1. INGEST      — prepare article text for analysis
  2. EXTRACT     — call Gemini to extract insights (claims, entities, sentiment, topics)
  3. EVALUATE    — assess implications and risk level
  4. RECOMMEND   — generate ranked action recommendations
  5. SIMULATE    — execute a chosen action and return before/after state

Each step produces a TraceStep for the execution log shown in the app.
"""

import time
import uuid
import json
from datetime import datetime, timezone
from typing import Optional

from ai.prompts import (
    INSIGHT_EXTRACTION_PROMPT,
    IMPLICATION_EVALUATION_PROMPT,
    ACTION_GENERATION_PROMPT,
)
from services.groq_service import generate_json
from services.news_service import fetch_article_body
from core.config import settings
from models.schemas import (
    Article,
    InsightResult,
    EvaluationResult,
    RecommendedAction,
    SimulationResult,
    AnalysisResponse,
    AgentTrace,
    TraceStep,
    ArticleState,
    ActionType,
    VerdictStatus,
    RiskLevel,
    ReliabilityBadge,
    SentimentLabel,
    NamedEntity,
    SimulateRequest,
)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _reliability_score(source_id: Optional[str]) -> float:
    if not source_id:
        return settings.DEFAULT_RELIABILITY
    return settings.KNOWN_RELIABLE_SOURCES.get(source_id, settings.DEFAULT_RELIABILITY)


def _reliability_badge(score: float) -> ReliabilityBadge:
    if score >= 0.70:
        return ReliabilityBadge.GREEN
    if score >= 0.40:
        return ReliabilityBadge.AMBER
    return ReliabilityBadge.RED


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)


# ─── Step 1: INGEST ───────────────────────────────────────────────────────────

async def _step_ingest(article: Article) -> tuple[str, TraceStep]:
    t = time.perf_counter()
    # Build best available content
    body = article.content or article.description or ""
    if len(body) < 200 and article.url:
        fetched = await fetch_article_body(article.url)
        if fetched:
            body = fetched

    # Fallback content
    if not body:
        body = f"{article.title}. {article.description or ''}"

    body = body[:4000]  # cap at 4K chars
    step = TraceStep(
        step="INGEST",
        duration_ms=_ms(t),
        status="SUCCESS",
        output_summary=f"Article body prepared ({len(body)} chars). Source: {article.source.name}",
    )
    return body, step


# ─── Step 2: EXTRACT INSIGHTS ─────────────────────────────────────────────────

async def _step_extract(article: Article, body: str) -> tuple[InsightResult, TraceStep]:
    t = time.perf_counter()
    prompt = INSIGHT_EXTRACTION_PROMPT.format(
        title=article.title,
        source=article.source.name,
        content=body,
    )
    try:
        data, tokens = await generate_json(prompt)
        insight = InsightResult(
            summary=data.get("summary", "No summary available."),
            key_claims=data.get("key_claims", []),
            named_entities=[
                NamedEntity(name=e["name"], type=e.get("type", "CONCEPT"))
                for e in data.get("named_entities", [])
            ],
            topics=data.get("topics", []),
            sentiment=SentimentLabel(data.get("sentiment", "NEUTRAL")),
            sentiment_score=float(data.get("sentiment_score", 0.0)),
            credibility_signals=data.get("credibility_signals", []),
            language=data.get("language", "en"),
        )
        step = TraceStep(
            step="EXTRACT_INSIGHTS",
            duration_ms=_ms(t),
            tokens_used=tokens,
            status="SUCCESS",
            output_summary=(
                f"Extracted {len(insight.key_claims)} claims, "
                f"{len(insight.named_entities)} entities, "
                f"sentiment={insight.sentiment.value}"
            ),
        )
    except Exception as e:
        # Graceful degradation — return minimal insight
        insight = InsightResult(
            summary=article.description or article.title,
            key_claims=[article.title],
            named_entities=[],
            topics=["General"],
            sentiment=SentimentLabel.NEUTRAL,
            sentiment_score=0.0,
            credibility_signals=["Unable to extract detailed signals"],
        )
        step = TraceStep(
            step="EXTRACT_INSIGHTS",
            duration_ms=_ms(t),
            status="DEGRADED",
            output_summary=f"Groq extraction failed ({e}). Using fallback.",
        )
    return insight, step


# ─── Step 3: EVALUATE IMPLICATIONS ────────────────────────────────────────────

async def _step_evaluate(
    article: Article, insight: InsightResult
) -> tuple[EvaluationResult, TraceStep]:
    t = time.perf_counter()
    rel_score = _reliability_score(article.source.id)
    prompt = IMPLICATION_EVALUATION_PROMPT.format(
        title=article.title,
        source=article.source.name,
        reliability_score=round(rel_score, 2),
        summary=insight.summary,
        claims=", ".join(insight.key_claims),
        sentiment=insight.sentiment.value,
        sentiment_score=round(insight.sentiment_score, 2),
        credibility_signals=", ".join(insight.credibility_signals),
        topics=", ".join(insight.topics),
    )
    try:
        data, tokens = await generate_json(prompt)
        risk = RiskLevel(data.get("risk_level", "MEDIUM"))
        misinfo_prob = float(data.get("misinformation_probability", 0.3))
        evaluation = EvaluationResult(
            risk_level=risk,
            misinformation_probability=misinfo_prob,
            source_reliability=rel_score,
            reliability_badge=_reliability_badge(rel_score),
            flags=data.get("flags", []),
            reasoning=data.get("reasoning", ""),
        )
        step = TraceStep(
            step="EVALUATE_IMPLICATIONS",
            duration_ms=_ms(t),
            tokens_used=tokens,
            status="SUCCESS",
            output_summary=(
                f"Risk={risk.value}, "
                f"Misinfo prob={misinfo_prob:.0%}, "
                f"Source reliability={rel_score:.0%}"
            ),
        )
    except Exception as e:
        evaluation = EvaluationResult(
            risk_level=RiskLevel.MEDIUM,
            misinformation_probability=0.3,
            source_reliability=rel_score,
            reliability_badge=_reliability_badge(rel_score),
            flags=["Evaluation service degraded"],
            reasoning="Unable to complete full evaluation.",
        )
        step = TraceStep(
            step="EVALUATE_IMPLICATIONS",
            duration_ms=_ms(t),
            status="DEGRADED",
            output_summary=f"Evaluation failed ({e}). Defaults applied.",
        )
    return evaluation, step


# ─── Step 4: GENERATE ACTIONS ─────────────────────────────────────────────────

async def _step_recommend(
    article: Article, insight: InsightResult, evaluation: EvaluationResult
) -> tuple[list[RecommendedAction], TraceStep]:
    t = time.perf_counter()
    prompt = ACTION_GENERATION_PROMPT.format(
        title=article.title,
        risk_level=evaluation.risk_level.value,
        misinfo_prob=round(evaluation.misinformation_probability, 2),
        reliability=round(evaluation.source_reliability, 2),
        flags=", ".join(evaluation.flags) or "None",
        topics=", ".join(insight.topics),
    )
    try:
        data, tokens = await generate_json(prompt)
        actions = []
        for item in data:
            try:
                actions.append(
                    RecommendedAction(
                        id=item.get("id", f"action_{uuid.uuid4().hex[:6]}"),
                        type=ActionType(item.get("type", "FACT_CHECK")),
                        title=item.get("title", "Unnamed Action"),
                        description=item.get("description", ""),
                        rationale=item.get("rationale", ""),
                        priority=int(item.get("priority", 1)),
                        estimated_impact=item.get("estimated_impact", ""),
                        simulated_outcome=item.get("simulated_outcome", ""),
                    )
                )
            except Exception:
                continue
        actions.sort(key=lambda a: a.priority)
        step = TraceStep(
            step="GENERATE_ACTIONS",
            duration_ms=_ms(t),
            tokens_used=tokens,
            status="SUCCESS",
            output_summary=f"Generated {len(actions)} recommended actions",
        )
    except Exception as e:
        # Fallback default actions
        actions = _fallback_actions(evaluation)
        step = TraceStep(
            step="GENERATE_ACTIONS",
            duration_ms=_ms(t),
            status="DEGRADED",
            output_summary=f"Action generation failed ({e}). Fallback applied.",
        )
    return actions, step


def _fallback_actions(evaluation: EvaluationResult) -> list[RecommendedAction]:
    return [
        RecommendedAction(
            id="action_1",
            type=ActionType.FACT_CHECK,
            title="Initiate Fact-Check",
            description="Submit this article to fact-checkers for verification.",
            rationale=f"Risk level is {evaluation.risk_level.value}.",
            priority=1,
            estimated_impact="Verdict assigned within 2 hours.",
            simulated_outcome="Status changed from UNVERIFIED to FACT_CHECKED.",
        ),
        RecommendedAction(
            id="action_2",
            type=ActionType.SET_ALERT,
            title="Set Topic Alert",
            description="Get notified when similar articles appear.",
            rationale="Monitor this topic for developing narrative.",
            priority=2,
            estimated_impact="Real-time alerts for related stories.",
            simulated_outcome="Alert rule created. You will be notified of updates.",
        ),
    ]


# ─── Step 5: SIMULATE EXECUTION ───────────────────────────────────────────────

def simulate_action(req: SimulateRequest) -> SimulationResult:
    """
    Simulate what happens when the user picks an action.
    Returns before/after state change for the demo.
    """
    t = time.perf_counter()
    rel_score = _reliability_score(req.source_id)
    badge = _reliability_badge(rel_score)

    before = ArticleState(
        status=req.current_status,
        reliability_badge=badge,
        flags=[],
        last_action=None,
        processed_at=None,
    )

    log: list[str] = []
    now = _now_iso()

    if req.action_type == ActionType.FACT_CHECK:
        log = [
            f"[{now}] Received fact-check request for article: {req.article_id}",
            f"[{now}] Querying IFCN-certified fact-check database...",
            f"[{now}] Extracting verifiable claims from article content...",
            f"[{now}] Cross-referencing claims against 3 fact-check providers...",
            f"[{now}] Computing confidence scores for each claim...",
            f"[{now}] Fact-check pipeline complete. Verdict assigned.",
        ]
        after_status = VerdictStatus.FACT_CHECKED
        impact = "Article has been submitted to fact-checkers. Verdict will be assigned within 2 hours. Editors notified."

    elif req.action_type == ActionType.FLAG_MISINFORMATION:
        log = [
            f"[{now}] Flagging article {req.article_id} for misinformation review...",
            f"[{now}] Notifying editorial team...",
            f"[{now}] Adding DISPUTED badge to article...",
            f"[{now}] Article removed from trending recommendations.",
            f"[{now}] Flag logged in audit trail.",
        ]
        after_status = VerdictStatus.DISPUTED
        impact = "Article flagged as potentially disputed. Removed from trending. Editorial team alerted."

    elif req.action_type == ActionType.SET_ALERT:
        log = [
            f"[{now}] Creating alert rule for article topics...",
            f"[{now}] Saving alert preferences to user profile...",
            f"[{now}] Alert rule active. Monitoring topic streams...",
        ]
        after_status = req.current_status
        impact = "Alert created. You will receive real-time notifications for related news."

    elif req.action_type == ActionType.SHARE_WITH_EDITOR:
        log = [
            f"[{now}] Preparing article summary for editorial review...",
            f"[{now}] Sending article + AI analysis to editor queue...",
            f"[{now}] Editor notified via email and in-app notification.",
            f"[{now}] Article marked as PENDING editorial review.",
        ]
        after_status = VerdictStatus.PENDING
        impact = "Article and AI analysis sent to editorial queue. Editor will review within 30 minutes."

    else:  # ARCHIVE
        log = [
            f"[{now}] Archiving article {req.article_id}...",
            f"[{now}] Moving to long-term storage index...",
            f"[{now}] Article archived successfully.",
        ]
        after_status = VerdictStatus.VERIFIED
        impact = "Article archived in the verified content library."

    after = ArticleState(
        status=after_status,
        reliability_badge=badge,
        flags=[f"Processed by NewsRadar Agent at {now}"],
        last_action=req.action_type.value,
        processed_at=now,
    )

    return SimulationResult(
        action_type=req.action_type,
        before_state=before,
        execution_log=log,
        after_state=after,
        impact_summary=impact,
        duration_ms=_ms(t),
    )


# ─── Main Agent Entry Point ───────────────────────────────────────────────────

async def run_analysis(article: Article) -> AnalysisResponse:
    """
    Full 4-step analysis pipeline. Returns complete AnalysisResponse with trace.
    """
    pipeline_start = time.perf_counter()
    trace_id = f"tr_{uuid.uuid4().hex[:12]}"
    steps: list[TraceStep] = []

    # Step 1: Ingest
    body, step1 = await _step_ingest(article)
    steps.append(step1)

    # Step 2: Extract insights
    insight, step2 = await _step_extract(article, body)
    steps.append(step2)

    # Step 3: Evaluate implications
    evaluation, step3 = await _step_evaluate(article, insight)
    steps.append(step3)

    # Step 4: Generate recommended actions
    actions, step4 = await _step_recommend(article, insight, evaluation)
    steps.append(step4)

    total_ms = _ms(pipeline_start)
    trace = AgentTrace(
        trace_id=trace_id,
        article_id=article.id,
        article_title=article.title,
        timestamp=_now_iso(),
        total_duration_ms=total_ms,
        steps=steps,
    )

    return AnalysisResponse(
        article=article,
        insights=insight,
        evaluation=evaluation,
        recommended_actions=actions,
        trace=trace,
    )
