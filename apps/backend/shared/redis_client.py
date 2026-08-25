# shared/redis_client.py
"""
Redis client singleton using Upstash Redis REST API.

Key patterns:
  lock:job:{job_id}                  → NX EX 10 (distributed accept lock)
  job_notified:{job_id}:{worker_id}  → "pending" | "rejected", EX 300
  worker_state:{worker_id}           → cached availability, EX 60

Uses Upstash REST API (HTTP-based) — no persistent TCP connections,
perfect for Render web services.
"""
import os
from shared.logging import log

_redis_client = None
_redis_available = None


def _ensure_redis():
    """Lazy-initialize Upstash Redis REST client or local TCP Redis client. Returns True if available."""
    global _redis_client, _redis_available
    if _redis_available is not None:
        return _redis_available
    try:
        # Check if local mode
        env_mode = os.getenv("ENV", "production")
        if env_mode == "local" or os.getenv("QUEUE_MODE") == "local":
            import redis
            url = os.getenv("REDIS_URL")
            if not url:
                host = os.getenv("REDIS_HOST", "localhost")
                port = os.getenv("REDIS_PORT", "6379")
                url = f"redis://{host}:{port}"
            _redis_client = redis.Redis.from_url(url, decode_responses=True)
            _redis_client.ping()
            _redis_available = True
            log("redis", "_ensure_redis", "local_tcp_connected", url=url)
            return True

        from upstash_redis import Redis
        url = os.getenv("UPSTASH_REDIS_REST_URL", "")
        token = os.getenv("UPSTASH_REDIS_REST_TOKEN", "")
        if not url or not token:
            log("redis", "_ensure_redis", "no_credentials",
                severity="WARNING")
            _redis_available = False
            return False
        _redis_client = Redis(url=url, token=token)
        # Ping to verify connection
        _redis_client.ping()
        _redis_available = True
        log("redis", "_ensure_redis", "connected", url=url[:40])
    except Exception as e:
        _redis_available = False
        log("redis", "_ensure_redis", "unavailable",
            severity="WARNING", error=str(e))
    return _redis_available


def get_client():
    """Get the Redis client instance. Returns None if unavailable."""
    if _ensure_redis():
        return _redis_client
    return None


# ─── Distributed Lock ────────────────────────────────────────────

def acquire_lock(key: str, value: str, ex: int = 10) -> bool:
    """
    Acquire a distributed lock using SET NX EX.
    Returns True if lock acquired, False if already held.
    """
    if not _ensure_redis():
        # Fallback: allow through (Postgres accept_job_atomic is the real guard)
        log("redis", "acquire_lock", "fallback_no_redis",
            severity="WARNING", key=key)
        return True
    try:
        result = _redis_client.set(key, value, nx=True, ex=ex)
        acquired = result is True or result == "OK"
        log("redis", "acquire_lock",
            "acquired" if acquired else "already_held",
            key=key, value=value)
        return acquired
    except Exception as e:
        log("redis", "acquire_lock", "error",
            severity="WARNING", key=key, error=str(e))
        return True  # Fallback to Postgres atomic transaction


def release_lock(key: str) -> bool:
    """Release a distributed lock."""
    if not _ensure_redis():
        return True
    try:
        _redis_client.delete(key)
        return True
    except Exception as e:
        log("redis", "release_lock", "error",
            severity="WARNING", key=key, error=str(e))
        return False


# ─── State Management ────────────────────────────────────────────

def set_state(key: str, value: str, ex: int = 300) -> bool:
    """Set a state key with expiry."""
    if not _ensure_redis():
        return False
    try:
        _redis_client.set(key, value, ex=ex)
        return True
    except Exception as e:
        log("redis", "set_state", "error",
            severity="WARNING", key=key, error=str(e))
        return False


def get_state(key: str) -> str | None:
    """Get a state value."""
    if not _ensure_redis():
        return None
    try:
        return _redis_client.get(key)
    except Exception as e:
        log("redis", "get_state", "error",
            severity="WARNING", key=key, error=str(e))
        return None


def count_by_pattern(pattern: str) -> dict[str, str]:
    """
    Scan keys matching a pattern and return {key: value} dict.
    Used to check how many workers have responded to a job notification.
    """
    if not _ensure_redis():
        return {}
    try:
        result = {}
        cursor = 0
        while True:
            cursor, keys = _redis_client.scan(cursor=cursor, match=pattern, count=50)
            for k in keys:
                result[k] = _redis_client.get(k) or ""
            if cursor == 0:
                break
        return result
    except Exception as e:
        log("redis", "count_by_pattern", "error",
            severity="WARNING", pattern=pattern, error=str(e))
        return {}
