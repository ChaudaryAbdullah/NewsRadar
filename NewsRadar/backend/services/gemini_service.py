"""
Gemini API wrapper — all calls to Google Generative AI go through here.
Swap the model or provider by changing this file only.
"""

import os
import json
import re
import google.generativeai as genai
from core.config import settings


def _configure():
    genai.configure(api_key=settings.GEMINI_API_KEY)


def _get_model() -> genai.GenerativeModel:
    _configure()
    return genai.GenerativeModel(
        model_name=settings.GEMINI_MODEL,
        generation_config=genai.GenerationConfig(
            temperature=settings.GEMINI_TEMPERATURE,
            max_output_tokens=settings.GEMINI_MAX_TOKENS,
        ),
    )


def _parse_json(text: str) -> dict | list:
    """Strip markdown fences and parse JSON from LLM response."""
    # Remove ```json ... ``` or ``` ... ``` wrappers if present
    text = re.sub(r"```(?:json)?\s*", "", text).strip()
    text = re.sub(r"```$", "", text).strip()
    return json.loads(text)


async def generate(prompt: str) -> tuple[str, int]:
    """
    Send a prompt to Gemini and return (response_text, tokens_used).
    """
    model = _get_model()
    # google-generativeai is sync; run in thread pool for FastAPI async compat
    import asyncio
    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(
        None, lambda: model.generate_content(prompt)
    )
    text = response.text.strip()
    # Token count — use usage_metadata if available
    tokens = 0
    try:
        tokens = response.usage_metadata.total_token_count or 0
    except Exception:
        tokens = len(prompt.split()) + len(text.split())  # rough estimate
    return text, tokens


async def generate_json(prompt: str) -> tuple[dict | list, int]:
    """Generate a prompt and parse the response as JSON."""
    text, tokens = await generate(prompt)
    parsed = _parse_json(text)
    return parsed, tokens
