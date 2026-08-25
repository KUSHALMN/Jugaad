import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.auth import router

app = FastAPI(title="Auth Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok", "service": "auth_service"}

# Mount the unified auth router under /v1/auth prefix
app.include_router(router, prefix="/v1/auth", tags=["Auth"])
