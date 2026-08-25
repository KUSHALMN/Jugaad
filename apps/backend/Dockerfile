# ============================================================================
# Jugaad Backend — Multi-stage Production Dockerfile
# ============================================================================
# Base image: python:3.11-slim
# Stages:
#   1. builder  — installs dependencies into a virtualenv
#   2. runtime  — copies only the virtualenv + app code (smaller final image)
#
# Build:
#   docker build -t jugaad-backend .
#
# Run (standalone):
#   docker run -p 8000:8000 --env-file .env jugaad-backend
#
# Recommended: use docker-compose.yml instead (includes Redis).
# ============================================================================

# ─── Stage 1: Builder ───────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Install build dependencies required by some Python packages (e.g. cryptography)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libffi-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a virtualenv so we can copy it cleanly to the runtime stage
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies (cached layer — only rebuilds when requirements change)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt


# ─── Stage 2: Runtime ───────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Labels for container metadata
LABEL maintainer="Jugaad App Team" \
      description="Jugaad Backend — Hyperlocal Worker Marketplace API" \
      version="1.0.0"

# Runtime env vars
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PORT=8000

WORKDIR /app

# Install minimal runtime dependencies (libpq for psycopg if needed)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-built virtualenv from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY core/        ./core/
COPY shared/      ./shared/
COPY routers/     ./routers/
COPY services/    ./services/
COPY gateway/     ./gateway/
COPY main.py      ./main.py

# Copy Firebase credentials file if it exists (will be mounted via volume in dev)
# In production, use FIREBASE_CREDENTIALS_JSON env var instead
COPY firebase-credentials.json* ./

# Create a non-root user for security
RUN groupadd -r jugaad && \
    useradd -r -g jugaad -d /app -s /sbin/nologin jugaad && \
    chown -R jugaad:jugaad /app

USER jugaad

# Expose the API port
EXPOSE 8000

# Health check — ensures the container is serving traffic
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# ─── Entry Point ────────────────────────────────────────────────────────────
# Production: single worker, no reload
# For development with hot reload, override via docker-compose command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--log-level", "info"]
