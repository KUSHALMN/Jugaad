"""
core/idempotency.py
Enterprise Idempotency Middleware and Helper for Jugaad Backend.

Guarantees Exactly-Once execution semantics for critical financial, dispatch,
and job lifecycle mutations by caching execution outcomes keyed by Idempotency-Key.
"""
import json
import logging
from typing import Optional, Any
from fastapi import Request, HTTPException
from shared import redis_client

logger = logging.getLogger(__name__)

IDEMPOTENCY_HEADER = "idempotency-key"
ALT_HEADER = "x-idempotency-key"
DEFAULT_TTL = 120  # 2 minutes cache window


def extract_idempotency_key(request: Request) -> Optional[str]:
    """Extract idempotency key from request headers if provided."""
    headers = request.headers
    key = headers.get(IDEMPOTENCY_HEADER) or headers.get(ALT_HEADER)
    if key:
        return key.strip()
    return None


def acquire_idempotency_in_flight(key: str, scope: str = "mutation") -> bool:
    """
    Acquire in-flight execution lock for the idempotency key.
    Returns False if another request with this key is already executing.
    """
    lock_key = f"idemp:lock:{scope}:{key}"
    return redis_client.acquire_lock(lock_key, "in_flight", ex=15)


def release_idempotency_in_flight(key: str, scope: str = "mutation") -> bool:
    """Release the in-flight lock after execution completes."""
    lock_key = f"idemp:lock:{scope}:{key}"
    return redis_client.release_lock(lock_key)


def get_cached_idempotency_response(key: str, scope: str = "mutation") -> Optional[dict]:
    """Retrieve previously cached response for this idempotency key."""
    cache_key = f"idemp:resp:{scope}:{key}"
    raw = redis_client.get_state(cache_key)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception as e:
        logger.warning(f"Failed to decode cached idempotency response: {e}")
        return None


def cache_idempotency_response(
    key: str,
    response_data: Any,
    ttl: int = DEFAULT_TTL,
    scope: str = "mutation"
) -> bool:
    """Cache the successful response payload for the idempotency key."""
    cache_key = f"idemp:resp:{scope}:{key}"
    try:
        payload = json.dumps(response_data, default=str)
        return redis_client.set_state(cache_key, payload, ex=ttl)
    except Exception as e:
        logger.warning(f"Failed to cache idempotency response: {e}")
        return False
