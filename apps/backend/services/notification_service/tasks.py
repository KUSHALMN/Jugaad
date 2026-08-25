# services/notification_service/tasks.py
"""
Retry/DLQ task scheduling via QStash (replaces Google Cloud Tasks).
When a notification fails, we schedule a retry with exponential backoff.
"""
import os
from shared.qstash import enqueue_task
from shared.logging import log

# The notification service URL routed through API Gateway
NOTIFICATION_SERVICE_URL = os.getenv(
    "NOTIFICATION_SERVICE_URL",
    "https://jugaad-gateway-9ilmeeco.uc.gateway.dev/internal/notify"
)


def create_retry_task(payload: dict, retries: int = 0):
    """
    Schedules a retry via QStash with exponential backoff.
    Max 3 retries: 5min → 25min → 125min
    """
    if retries > 3:
        log("notification_tasks", "create_retry_task", "max_retries_exceeded",
            payload=str(payload), severity="ERROR")
        return

    delay_seconds = (5 * 60) * (5 ** retries)  # 300s, 1500s, 7500s

    try:
        message_id = enqueue_task(
            url=NOTIFICATION_SERVICE_URL,
            body={"payload": payload, "retries": retries + 1},
            delay_seconds=delay_seconds,
        )
        log("notification_tasks", "create_retry_task", "scheduled",
            message_id=message_id, retries=retries + 1, delay_seconds=delay_seconds)
    except Exception as e:
        log("notification_tasks", "create_retry_task", "failed",
            error=str(e), severity="ERROR")
