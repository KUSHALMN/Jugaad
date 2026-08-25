import os

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# 1. shared/pubsub.py
shared_pubsub = """
import os
import json
from google.cloud import pubsub_v1
from shared.logging import log

project_id = os.getenv("PUBSUB_PROJECT_ID", os.getenv("GOOGLE_CLOUD_PROJECT", ""))
publisher = pubsub_v1.PublisherClient()
subscriber = pubsub_v1.SubscriberClient()

def publish_event(topic_name: str, event_type: str, job_id: str, version: int, payload: dict, event_id: str = "") -> str:
    topic_path = publisher.topic_path(project_id, topic_name)
    data = json.dumps({
        "event_type": event_type,
        "event_id": event_id,
        "job_id": job_id,
        "version": version,
        "payload": payload,
    }).encode("utf-8")
    try:
        future = publisher.publish(topic_path, data, ordering_key=job_id)
        msg_id = future.result()
        log("pubsub", "publish", "ok", msg_id=msg_id)
        return msg_id
    except Exception as e:
        log("pubsub", "publish", "fail", error=str(e))
        raise

def subscribe_topic(subscription_name: str, callback):
    subscription_path = subscriber.subscription_path(project_id, subscription_name)
    def wrapped(message):
        try:
            callback(message)
            message.ack()
        except Exception as e:
            log("pubsub", "subscribe", "fail", error=str(e))
            message.nack()
    try:
        future = subscriber.subscribe(subscription_path, callback=wrapped)
        return future
    except Exception as e:
        log("pubsub", "subscribe_start", "fail", error=str(e))
        raise
"""
write_file("shared/pubsub.py", shared_pubsub)

# 2. auth-service
auth_main = """
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, ConfigDict
import requests
import os
import uuid
from shared.firestore import db
from shared.auth import verify_oidc_token

app = FastAPI()
MSG91_AUTHKEY = os.getenv("MSG91_API_KEY")
MSG91_TEMPLATE_ID = os.getenv("MSG91_FLOW_ID_OTP")

class SendOtpRequest(BaseModel):
    phone: str

class VerifyOtpRequest(BaseModel):
    phone: str
    otp: str

@app.post("/v1/auth/send-otp")
def send_otp(req: SendOtpRequest):
    # Bug 10 Fix: Flow based OTP (v5)
    url = "https://control.msg91.com/api/v5/otp"
    payload = {"template_id": MSG91_TEMPLATE_ID, "mobile": "91" + req.phone}
    headers = {"authkey": MSG91_AUTHKEY, "accept": "application/json", "content-type": "application/json"}
    resp = requests.post(url, json=payload, headers=headers)
    if resp.status_code != 200:
        raise HTTPException(400, "Failed to send OTP")
    return {"message": "OTP sent"}

@app.post("/v1/auth/verify-otp")
def verify_otp(req: VerifyOtpRequest):
    url = f"https://control.msg91.com/api/v5/otp/verify?otp={req.otp}&mobile=91{req.phone}"
    headers = {"authkey": MSG91_AUTHKEY}
    resp = requests.get(url, headers=headers)
    data = resp.json()
    if data.get("type") != "success":
        raise HTTPException(401, "Invalid OTP")
    
    # Check if user exists
    users = db.collection("users").where("phone", "==", req.phone).limit(1).get()
    workers = db.collection("workers").where("phone", "==", req.phone).limit(1).get()
    
    role = "none"
    uid = str(uuid.uuid4())
    if users:
        role = "user"
        uid = users[0].id
    elif workers:
        role = "worker"
        uid = workers[0].id
    else:
        # Issue a temporary token to register
        pass
    
    # In a real scenario we use Firebase Auth custom token minting:
    # custom_token = fb_auth.create_custom_token(uid, {"role": role})
    # But for now just return success
    return {"message": "OTP verified", "uid": uid, "role": role}
"""
write_file("services/auth-service/main.py", auth_main)
write_file("services/auth-service/__init__.py", "")
write_file("services/auth-service/Dockerfile", """FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY shared /app/shared
COPY services/auth-service /app/services/auth-service
ENV PYTHONPATH=/app
CMD ["uvicorn", "services.auth-service.main:app", "--host", "0.0.0.0", "--port", "8080"]
""")

print("Part 1 built")
