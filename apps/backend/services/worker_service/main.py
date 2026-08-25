import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.workers import router

app = FastAPI(title="Worker Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok", "service": "worker_service"}

# Mount the unified workers router under /v1/workers prefix
app.include_router(router, prefix="/v1/workers", tags=["Workers"])
