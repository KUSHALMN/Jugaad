import httpx
import os
from shared.database import supabase

INTERNAL_SECRET = os.getenv("INTERNAL_SECRET")
MATCHING_SERVICE_URL = os.getenv("MATCHING_SERVICE_URL")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL")

async def publish_event(event_type: str, job_id: str, payload: dict):
    """
    Replaces Google Pub/Sub publisher.
    
    OLD PATTERN:
        publisher.publish(topic_path, data=json.dumps(payload).encode())
    
    NEW PATTERN:
        1. Write to outbox_events table (Postgres trigger fires automatically)
        2. Trigger calls ops-service /internal/outbox/dispatch via pg_net
        3. ops-service routes to correct downstream service
    """
    # Write to outbox (trigger handles delivery)
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": event_type,
        "payload": payload,
        "published": False
    }).execute()

async def dispatch_direct(service_url: str, endpoint: str, payload: dict):
    """
    Direct HTTP call to internal service (fallback if pg_net trigger fails)
    Replaces Pub/Sub push subscription delivery
    """
    headers = {
        "Content-Type": "application/json",
        "X-Internal-Secret": INTERNAL_SECRET
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        await client.post(f"{service_url}{endpoint}", json=payload, headers=headers)
