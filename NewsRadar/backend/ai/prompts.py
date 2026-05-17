"""
All LLM prompt templates for the NewsRadar AI agent.
Keeping prompts isolated here makes them easy to tune without touching agent logic.
"""

INSIGHT_EXTRACTION_PROMPT = """
You are NewsRadar's AI analyst. Analyze the following news article and extract structured insights.

ARTICLE TITLE: {title}
ARTICLE SOURCE: {source}
ARTICLE CONTENT:
{content}

Return a JSON object with EXACTLY this structure (no extra keys, no markdown fences):
{{
  "summary": "2-3 sentence abstractive summary of the article",
  "key_claims": ["claim 1", "claim 2", "claim 3"],
  "named_entities": [
    {{"name": "Entity Name", "type": "PERSON|ORGANIZATION|LOCATION|EVENT|CONCEPT"}}
  ],
  "topics": ["topic1", "topic2", "topic3"],
  "sentiment": "POSITIVE|NEGATIVE|NEUTRAL",
  "sentiment_score": 0.0,
  "credibility_signals": ["signal 1", "signal 2"],
  "language": "en"
}}

Rules:
- key_claims: 2-5 specific, verifiable claims made in the article
- named_entities: up to 8 entities, use type PERSON/ORGANIZATION/LOCATION/EVENT/CONCEPT
- topics: 2-5 broad topic tags (e.g. "Politics", "Technology", "Climate Change")
- sentiment_score: float from -1.0 (very negative) to 1.0 (very positive)
- credibility_signals: observable signals about credibility (quotes sources, has byline, speculative language, etc.)
- Return ONLY valid JSON, nothing else
"""

IMPLICATION_EVALUATION_PROMPT = """
You are NewsRadar's integrity evaluator. Given the article insights below, assess the risk and implications.

ARTICLE TITLE: {title}
SOURCE: {source}
SOURCE RELIABILITY SCORE: {reliability_score} (0.0 = unreliable, 1.0 = highly reliable)

EXTRACTED INSIGHTS:
- Summary: {summary}
- Key Claims: {claims}
- Sentiment: {sentiment} (score: {sentiment_score})
- Credibility Signals: {credibility_signals}
- Topics: {topics}

Return a JSON object with EXACTLY this structure:
{{
  "risk_level": "LOW|MEDIUM|HIGH",
  "misinformation_probability": 0.0,
  "flags": ["flag 1", "flag 2"],
  "reasoning": "1-2 sentence explanation of the risk assessment"
}}

Rules:
- risk_level HIGH if: misinformation_prob > 0.6 OR source reliability < 0.4 OR has inflammatory claims
- risk_level MEDIUM if: misinformation_prob 0.3-0.6 OR source reliability 0.4-0.7
- risk_level LOW if: misinformation_prob < 0.3 AND source reliability > 0.7
- flags: specific concerns found (e.g. "Unverified statistics", "Anonymous sources only", "Emotionally charged language")
- Return ONLY valid JSON, nothing else
"""

ACTION_GENERATION_PROMPT = """
You are NewsRadar's action recommendation engine. Based on the article analysis, generate 3-4 concrete recommended actions.

ARTICLE: {title}
RISK LEVEL: {risk_level}
MISINFORMATION PROBABILITY: {misinfo_prob}
SOURCE RELIABILITY: {reliability}
FLAGS: {flags}
TOPICS: {topics}

Available action types: FACT_CHECK, SET_ALERT, FLAG_MISINFORMATION, SHARE_WITH_EDITOR, ARCHIVE

Return a JSON array with EXACTLY this structure:
[
  {{
    "id": "action_1",
    "type": "FACT_CHECK|SET_ALERT|FLAG_MISINFORMATION|SHARE_WITH_EDITOR|ARCHIVE",
    "title": "Short action title (max 6 words)",
    "description": "1-2 sentence description of what this action does",
    "rationale": "Why this action is recommended given the analysis",
    "priority": 1,
    "estimated_impact": "Expected outcome if action is taken",
    "simulated_outcome": "Specific state change: e.g. 'Article status changed from UNVERIFIED to FLAGGED. Editor notified.'"
  }}
]

Rules:
- Priority 1 = most urgent. Always rank by urgency.
- HIGH risk → always include FLAG_MISINFORMATION or FACT_CHECK as priority 1
- Include SET_ALERT if topics are newsworthy and ongoing
- simulated_outcome must be specific and concrete
- Return ONLY valid JSON array, nothing else
"""
