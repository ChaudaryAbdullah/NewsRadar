from pydantic import BaseModel
from typing import Optional, List
from enum import Enum


# ─── Enums ────────────────────────────────────────────────────────────────────

class SentimentLabel(str, Enum):
    POSITIVE = "POSITIVE"
    NEGATIVE = "NEGATIVE"
    NEUTRAL = "NEUTRAL"


class RiskLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class VerdictStatus(str, Enum):
    UNVERIFIED = "UNVERIFIED"
    FLAGGED = "FLAGGED"
    FACT_CHECKED = "FACT_CHECKED"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"
    PENDING = "PENDING"
    MISINFORMATION = "MISINFORMATION"


class ActionType(str, Enum):
    FACT_CHECK = "FACT_CHECK"
    SET_ALERT = "SET_ALERT"
    FLAG_MISINFORMATION = "FLAG_MISINFORMATION"
    SHARE_WITH_EDITOR = "SHARE_WITH_EDITOR"
    ARCHIVE = "ARCHIVE"
    QUARANTINE = "QUARANTINE"
    AMPLIFY = "AMPLIFY"
    REQUEST_COMMENT = "REQUEST_COMMENT"


class ReliabilityBadge(str, Enum):
    GREEN = "GREEN"
    AMBER = "AMBER"
    RED = "RED"


# ─── Article Models ───────────────────────────────────────────────────────────

class ArticleSource(BaseModel):
    id: Optional[str] = None
    name: str


class Article(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    content: Optional[str] = None
    url: str
    urlToImage: Optional[str] = None
    publishedAt: str
    source: ArticleSource
    author: Optional[str] = None
    status: VerdictStatus = VerdictStatus.UNVERIFIED


class ArticleListResponse(BaseModel):
    articles: List[Article]
    total: int
    page: int
    page_size: int


# ─── Insight Models ───────────────────────────────────────────────────────────

class NamedEntity(BaseModel):
    name: str
    type: str  # PERSON | ORGANIZATION | LOCATION | EVENT | CONCEPT


class InsightResult(BaseModel):
    summary: str
    key_claims: List[str]
    named_entities: List[NamedEntity]
    topics: List[str]
    sentiment: SentimentLabel
    sentiment_score: float   # -1.0 to 1.0
    credibility_signals: List[str]
    language: str = "en"


# ─── Evaluation Models ────────────────────────────────────────────────────────

class EvaluationResult(BaseModel):
    risk_level: RiskLevel
    misinformation_probability: float   # 0.0 – 1.0
    source_reliability: float            # 0.0 – 1.0
    reliability_badge: ReliabilityBadge
    flags: List[str]
    reasoning: str


# ─── Action Models ────────────────────────────────────────────────────────────

class RecommendedAction(BaseModel):
    id: str
    type: ActionType
    title: str
    description: str
    rationale: str
    priority: int   # 1 = highest priority
    estimated_impact: str
    simulated_outcome: str


# ─── Simulation Models ────────────────────────────────────────────────────────

class ArticleState(BaseModel):
    status: VerdictStatus
    reliability_badge: ReliabilityBadge
    flags: List[str]
    last_action: Optional[str] = None
    processed_at: Optional[str] = None


class SimulationResult(BaseModel):
    action_type: ActionType
    before_state: ArticleState
    execution_log: List[str]
    after_state: ArticleState
    impact_summary: str
    duration_ms: int


# ─── Agent Trace Models ───────────────────────────────────────────────────────

class TraceStep(BaseModel):
    step: str
    duration_ms: int
    tokens_used: Optional[int] = None
    status: str = "SUCCESS"
    output_summary: str


class AgentTrace(BaseModel):
    trace_id: str
    article_id: str
    article_title: str
    timestamp: str
    total_duration_ms: int
    steps: List[TraceStep]


# ─── Full Analysis Response ───────────────────────────────────────────────────

class AnalysisResponse(BaseModel):
    article: Article
    insights: InsightResult
    evaluation: EvaluationResult
    recommended_actions: List[RecommendedAction]
    trace: AgentTrace


# ─── Simulation Request ───────────────────────────────────────────────────────

class SimulateRequest(BaseModel):
    article_id: str
    article_title: str
    article_url: str
    source_name: str
    source_id: Optional[str] = None
    current_status: VerdictStatus
    current_reliability: float
    action_type: ActionType
