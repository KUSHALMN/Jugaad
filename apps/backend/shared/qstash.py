# shared/qstash.py
"""
QStash task queue with LOCAL MODE support.

When QUEUE_MODE=local (or ENV=local), tasks are executed locally
using asyncio delayed coroutines instead of calling the cloud QStash API.
This eliminates the need for Upstash QStash in local development.

When QUEUE_MODE=qstash, the original Upstash QStash HTTP API is used.
"""
import asyncio
import httpx
import json
import os
import uuid
from shared.logging import log
from core.config import settings

QSTASH_TOKEN = os.getenv("QSTASH_TOKEN")
QSTASH_BASE = "https://qstash.upstash.io/v2/publish"


async def _execute_local_task(url: str, body: dict, delay_seconds: int):
    """Execute a delayed task locally using asyncio.sleep + httpx POST to localhost."""
    task_id = uuid.uuid4().hex[:8]
    log("qstash_local", "_execute_local_task", "scheduled",
        task_id=task_id, url=url, delay_seconds=delay_seconds)

    if delay_seconds > 0:
        await asyncio.sleep(delay_seconds)

    # POST to local server
    local_url = url
    if url.startswith("http"):
        # If it's already a full URL, try to rewrite to localhost
        # e.g., https://your-render-url.com/internal/timeout → http://localhost:8000/internal/timeout
        from urllib.parse import urlparse
        parsed = urlparse(url)
        local_url = f"http://localhost:{settings.PORT}{parsed.path}"
    elif not url.startswith("/"):
        local_url = f"http://localhost:{settings.PORT}/{url}"
    else:
        local_url = f"http://localhost:{settings.PORT}{url}"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(local_url, json=body)
            log("qstash_local", "_execute_local_task", "delivered",
                task_id=task_id, url=local_url, status=resp.status_code)
    except Exception as e:
        log("qstash_local", "_execute_local_task", "delivery_failed",
            severity="WARNING", task_id=task_id, url=local_url, error=str(e))


def enqueue_task(url: str, body: dict, delay_seconds: int = 0) -> str:
    """
    Publishes a delayed task.

    LOCAL MODE: Fires an asyncio background task with sleep delay.
    CLOUD MODE: Uses QStash /v2/publish endpoint.
    """
    if settings.QUEUE_MODE == "local":
        task_id = f"local_{uuid.uuid4().hex[:12]}"
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                loop.create_task(_execute_local_task(url, body, delay_seconds))
            else:
                asyncio.run(_execute_local_task(url, body, delay_seconds))
        except RuntimeError:
            # No event loop — create one
            asyncio.run(_execute_local_task(url, body, delay_seconds))

        log("qstash", "enqueue_task", "local_queued",
            url=url, delay_seconds=delay_seconds, task_id=task_id)
        return task_id

    # Cloud QStash mode
    headers = {
        "Authorization": f"Bearer {QSTASH_TOKEN}",
        "Content-Type": "application/json",
        "Upstash-Delay": f"{delay_seconds}s",
        "Upstash-Retries": "3",
    }
    resp = httpx.post(
        f"{QSTASH_BASE}/{url}",
        headers=headers,
        content=json.dumps(body),
        timeout=10,
    )
    resp.raise_for_status()
    message_id = resp.json().get("messageId", "unknown")
    log("qstash", "enqueue_task", "published",
        url=url, delay_seconds=delay_seconds, message_id=message_id)
    return message_id


def enqueue_delayed(url: str, delay_seconds: int, payload: dict) -> str:
    """
    Publishes a delayed task.

    LOCAL MODE: Same as enqueue_task with delay.
    CLOUD MODE: Uses QStash /v2/enqueue endpoint.
    """
    if settings.QUEUE_MODE == "local":
        return enqueue_task(url, payload, delay_seconds)

    # Cloud QStash mode
    headers = {
        "Authorization": f"Bearer {QSTASH_TOKEN}",
        "Content-Type": "application/json",
        "Upstash-Delay": f"{delay_seconds}s",
    }

    request_url = f"https://qstash.upstash.io/v2/enqueue/{url}"

    with httpx.Client() as client:
        resp = client.post(
            request_url,
            headers=headers,
            json=payload,
            timeout=10.0,
        )

    if resp.status_code != 200:
        raise RuntimeError(
            f"QStash enqueue failed with status {resp.status_code}: {resp.text}"
        )

    data = resp.json()
    message_id = data.get("messageId") or data.get("message_id") or "unknown"
    log("qstash", "enqueue_delayed", "published",
        url=url, delay_seconds=delay_seconds, message_id=message_id)
    return message_id
