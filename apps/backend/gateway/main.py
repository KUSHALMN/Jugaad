from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from shared.database import supabase
from shared.auth import verify_internal_secret
import httpx
import os

app = FastAPI(title="Jugaad API Gateway")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


def service_url(name: str) -> str | None:
    value = os.getenv(name)
    if not value:
        return None
    if value.startswith(("http://", "https://")):
        return value.rstrip("/")
    return f"https://{value}".rstrip("/")


# Internal Render service URLs
SERVICES = {
    "request":      service_url("REQUEST_SERVICE_URL"),
    "matching":     service_url("MATCHING_SERVICE_URL"),
    "notification": service_url("NOTIFICATION_SERVICE_URL"),
    "job":          service_url("JOB_SERVICE_URL"),
    "worker":       service_url("WORKER_SERVICE_URL"),
    "booking":      service_url("BOOKING_SERVICE_URL"),
    "payment":      service_url("PAYMENT_SERVICE_URL"),
    "admin":        service_url("ADMIN_SERVICE_URL"),
    "review":       service_url("REVIEW_SERVICE_URL"),
    "auth":         service_url("AUTH_SERVICE_URL"),
    "user":         service_url("USER_SERVICE_URL"),
    "scheduler":    service_url("SCHEDULER_SERVICE_URL"),
}

# Route map: /v1/{resource} → service
ROUTE_MAP = {
    "jobs":      "job",
    "workers":   "worker",
    "bookings":  "booking",
    "payments":  "payment",
    "reviews":   "review",
    "auth":      "auth",
    "requests":  "request",
    "admin":     "admin",
    "users":     "user",
    "matching":  "matching",
    "services":  "request",
}

OUTBOX_EVENT_TARGETS = {
    "JOB_CREATED": "matching",
    "JOB_TIMEOUT": "matching",
    "JOB_SCHEDULED": "scheduler",
}


@app.api_route("/v1/{resource}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
@app.api_route("/v1/{resource}/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(resource: str, request: Request, path: str = ""):
    service_key = ROUTE_MAP.get(resource)
    
    # Custom routing for "jobs" resource to split between request_service and job_service
    if resource == "jobs":
        if path == "" and request.method == "POST":
            # Creating a job -> request_service
            service_key = "request"
        elif path and "/" not in path:
            # e.g. path is "{job_id}"
            if request.method in ("GET", "DELETE"):
                # Get job details or cancel/delete job -> request_service
                service_key = "request"
        elif path and (path.endswith("/cancel") or path.endswith("cancel")):
            # Cancel job -> request_service
            service_key = "request"

    if not service_key or not SERVICES.get(service_key):
        raise HTTPException(404, f"Unknown resource: {resource}")

    target_url = f"{SERVICES[service_key]}/v1/{resource}"
    if path:
        target_url = f"{target_url}/{path}"

    # Strip hop-by-hop headers that cause issues with internal routing
    fwd_headers = {k: v for k, v in request.headers.items()
                   if k.lower() not in ("host", "content-length", "transfer-encoding")}

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.request(
            method=request.method,
            url=target_url,
            headers=fwd_headers,
            content=await request.body(),
            params=dict(request.query_params),
        )

    # Exclude hop-by-hop headers from internal response back to client
    resp_headers = {k: v for k, v in response.headers.items()
                    if k.lower() not in ("content-length", "transfer-encoding", "content-encoding")}

    return Response(
        content=response.content,
        status_code=response.status_code,
        headers=resp_headers,
    )


@app.post("/internal/outbox/dispatch")
async def dispatch_outbox_event(request: Request):
    verify_internal_secret(request)
    event = await request.json()

    event_id = event.get("id")
    event_type = event.get("event_type", "")
    target_key = OUTBOX_EVENT_TARGETS.get(event_type, "notification")
    target_base = SERVICES.get(target_key)
    if not target_base:
        raise HTTPException(503, f"Missing service URL for {target_key}")

    target_path = {
        "matching": "/internal/match",
        "scheduler": "/internal/schedule",
        "notification": "/internal/notify",
    }[target_key]

    headers = {
        "Content-Type": "application/json",
        "X-Internal-Secret": os.getenv("INTERNAL_SECRET", ""),
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{target_base}{target_path}",
                json=event,
                headers=headers,
            )
        response.raise_for_status()
    except Exception as exc:
        if event_id:
            supabase.table("outbox_events").update({
                "retry_count": int(event.get("retry_count") or 0) + 1,
            }).eq("id", event_id).execute()
        raise HTTPException(502, f"Outbox dispatch failed: {exc}") from exc

    if event_id:
        supabase.table("outbox_events").update({"published": True}).eq("id", event_id).execute()

    return {
        "status": "ok",
        "event_id": event_id,
        "event_type": event_type,
        "target": target_key,
    }


@app.get("/health")
async def health():
    return {"status": "ok", "service": "gateway"}
