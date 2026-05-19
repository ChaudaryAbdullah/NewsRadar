"""
Groq API wrapper — all calls to Groq go through here.
Swap the model or provider by changing this file only.
"""

import os
import json
import re
from groq import AsyncGroq
from core.config import settings

def _get_client() -> AsyncGroq:
    return AsyncGroq(api_key=settings.GROQ_API_KEY)

def _parse_json(text: str) -> dict | list:
    """Strip markdown fences and parse JSON from LLM response."""
    # Remove ```json ... ``` or ``` ... ``` wrappers if present
    text = re.sub(r"```(?:json)?\s*", "", text).strip()
    text = re.sub(r"```$", "", text).strip()
    return json.loads(text)

async def generate(prompt: str) -> tuple[str, int]:
    """
    Send a prompt to Groq and return (response_text, tokens_used).
    """
    client = _get_client()
    response = await client.chat.completions.create(
        model=settings.GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=settings.GROQ_TEMPERATURE,
        max_tokens=settings.GROQ_MAX_TOKENS,
    )
    
    text = response.choices[0].message.content.strip()
    # Token count
    tokens = response.usage.total_tokens if response.usage else 0
    return text, tokens

async def generate_json(prompt: str) -> tuple[dict | list, int]:
    """Generate a prompt and parse the response as JSON."""
    text, tokens = await generate(prompt)
    parsed = _parse_json(text)
    return parsed, tokens
