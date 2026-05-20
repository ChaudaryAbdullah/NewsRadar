"""
Chatbot router — RAG-powered conversational AI endpoint.
POST /api/v1/chat/ask       — single-turn Q&A with source citations
POST /api/v1/chat/stream    — Server-Sent Events streaming response
POST /api/v1/chat/history   — get conversation context
"""

import json
import re
from datetime import datetime, timezone
from typing import AsyncGenerator

from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from services.groq_service import chat as groq_chat, stream_chat as groq_stream_chat

router = APIRouter(prefix="/api/v1/chat", tags=["Chatbot"])

# ── In-memory conversation history (per session, keyed by session_id) ──────────
_conversations: dict[str, list[dict]] = {}

SYSTEM_PROMPT = """You are NewsRadar AI — a smart, friendly, and highly capable news intelligence assistant embedded in the NewsRadar platform. You are also a great general conversation partner.

Language handling (CRITICAL):
- You understand BOTH English AND Roman Urdu (Urdu written in English letters, e.g., "Aaj ki khabrain kya hain?", "Kya haal hai?").
- ALWAYS detect the language the user writes in and respond in the SAME language/style.
- For Roman Urdu queries → respond in Roman Urdu naturally and warmly.
- For English queries → respond in clear, professional English.
- You can mix languages naturally if the user does (code-switching).

Your capabilities:
- Analyze and explain news articles, detecting misinformation and bias
- Provide source reliability context and cross-reference information  
- Answer questions about specific articles the user is viewing
- Explain AI verdicts (VERIFIED / UNVERIFIED / DISPUTED / MISINFORMATION)
- Summarize topics, trends, and key claims from recent news
- General conversation: jokes, greetings, casual chat, fun facts — you're not just a news bot!
- Pakistan news, global events, tech, finance, sports, entertainment

Personality:
- Warm, witty, helpful, and direct
- Use emojis naturally (not excessively)
- For casual messages like "kya haal hai?", "how are you?", "joke sunao" — respond naturally and warmly
- Don't be robotic. You're a companion, not just a tool.

Rules:
- Be concise but informative. Use bullet points for lists.
- If asked about an article, refer to the article context provided
- If you are uncertain about recent events, say so — do NOT hallucinate facts
- Keep responses under 350 words unless detail is specifically requested
- Format citations as: [Source Name](URL) at the end of relevant sentences

NewsRadar app features you can mention: news aggregation, AI pipelines, fact-checking, article analysis, personalization, voice assistant."""


class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"
    article_context: dict | None = None  # Pass current article for context


class ChatResponse(BaseModel):
    reply: str
    session_id: str
    sources: list[dict]
    timestamp: str


def _build_messages(session_id: str, user_msg: str, article_ctx: dict | None) -> list[dict]:
    """Build the messages list with conversation history + system prompt."""
    history = _conversations.get(session_id, [])

    context_str = ""
    if article_ctx:
        context_str = f"""
CURRENT ARTICLE CONTEXT:
Title: {article_ctx.get('title', '')}
Source: {article_ctx.get('source', '')}
URL: {article_ctx.get('url', '')}
Published: {article_ctx.get('published_at', '')}
Summary: {article_ctx.get('summary', '')}
Verdict: {article_ctx.get('verdict', '')}
Sentiment: {article_ctx.get('sentiment', '')}
Key Claims: {', '.join(article_ctx.get('key_claims', []))}
Entities: {', '.join(article_ctx.get('entities', []))}
---
"""

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    # Inject article context into the first user message of this turn
    full_user_msg = f"{context_str}{user_msg}" if context_str else user_msg

    messages.extend(history[-10:])  # keep last 10 turns for context
    messages.append({"role": "user", "content": full_user_msg})

    return messages


def _extract_sources(text: str, article_ctx: dict | None) -> list[dict]:
    """Extract markdown links from response as source citations."""
    sources = []
    pattern = r'\[([^\]]+)\]\((https?://[^\)]+)\)'
    for match in re.finditer(pattern, text):
        sources.append({"name": match.group(1), "url": match.group(2)})

    # Always include the article URL if context provided
    if article_ctx and article_ctx.get("url"):
        existing_urls = {s["url"] for s in sources}
        if article_ctx["url"] not in existing_urls:
            sources.insert(0, {
                "name": article_ctx.get("source", "Source Article"),
                "url": article_ctx["url"]
            })

    return sources


def _save_turn(session_id: str, user_msg: str, assistant_reply: str):
    """Persist conversation turn."""
    if session_id not in _conversations:
        _conversations[session_id] = []
    _conversations[session_id].append({"role": "user", "content": user_msg})
    _conversations[session_id].append({"role": "assistant", "content": assistant_reply})
    # Cap history at 30 messages
    if len(_conversations[session_id]) > 30:
        _conversations[session_id] = _conversations[session_id][-30:]


# ── Single-turn Q&A ────────────────────────────────────────────────────────────

@router.post("/ask", response_model=ChatResponse)
async def ask(req: ChatRequest):
    messages = _build_messages(req.session_id, req.message, req.article_context)
    reply = await groq_chat(messages)
    _save_turn(req.session_id, req.message, reply)
    return ChatResponse(
        reply=reply,
        session_id=req.session_id,
        sources=_extract_sources(reply, req.article_context),
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


# ── SSE Streaming ──────────────────────────────────────────────────────────────

@router.post("/stream")
async def stream_chat(req: ChatRequest):
    messages = _build_messages(req.session_id, req.message, req.article_context)

    async def event_generator() -> AsyncGenerator[str, None]:
        full_reply = ""
        try:
            async for chunk in groq_stream_chat(messages):
                full_reply += chunk
                data = json.dumps({"chunk": chunk, "done": False})
                yield f"data: {data}\n\n"

            # Save after complete
            _save_turn(req.session_id, req.message, full_reply)
            sources = _extract_sources(full_reply, req.article_context)
            done_data = json.dumps({
                "chunk": "",
                "done": True,
                "sources": sources,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })
            yield f"data: {done_data}\n\n"

        except Exception as e:
            err = json.dumps({"error": str(e), "done": True})
            yield f"data: {err}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


# ── Clear history ──────────────────────────────────────────────────────────────

@router.delete("/history/{session_id}")
async def clear_history(session_id: str):
    _conversations.pop(session_id, None)
    return {"cleared": session_id}
