import os
import shutil

SERVICES = [
    "auth-service",
    "user-service",
    "worker-service",
    "booking-service",
    "matching-service",
    "payment-service",
    "notification-service",
    "review-service",
    "admin-service"
]

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# Remove old services directory if we want a clean state.
old_services = ["admin_service", "job_service", "matching_service", "notification_service", "outbox_publisher", "payment_service", "request_service", "scheduler_service", "worker_service"]
for srv in old_services:
    path = os.path.join("services", srv)
    if os.path.exists(path):
        shutil.rmtree(path)

# Ensure services directory exists
os.makedirs("services", exist_ok=True)

# Generate basic main.py for all 9 services
for srv in SERVICES:
    main_content = f"""
from fastapi import FastAPI, Request
from shared.logging import log

app = FastAPI()

@app.get("/health")
def health():
    return {{"status": "ok", "service": "{srv}"}}
"""
    write_file(f"services/{srv}/main.py", main_content)
    write_file(f"services/{srv}/__init__.py", "")
    write_file(f"services/{srv}/Dockerfile", f"""
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY shared /app/shared
COPY services/{srv} /app/services/{srv}
ENV PYTHONPATH=/app
CMD ["uvicorn", "services.{srv}.main:app", "--host", "0.0.0.0", "--port", "8080"]
""")

print("Scaffolded 9 microservices")
