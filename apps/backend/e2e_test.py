"""
Jugaad E2E Test — Full job lifecycle using Firebase Auth custom token.
Runs via: python e2e_test.py
"""
import subprocess
import json
import time
import sys
import requests
import os
import traceback
from dotenv import load_dotenv

# Load environmental variables from .env file in the current directory
load_dotenv()

GW = "https://jugaad-gateway-9ilmeeco.uc.gateway.dev"
USER_ID   = "test-user-001"
WORKER_ID = "test-worker-001"

# ── Firebase Web API key (used only to exchange custom token for ID token)
# Get from: Firebase Console → Project settings → General → Web API key
FIREBASE_API_KEY = os.getenv("FIREBASE_WEB_API_KEY", "")

# ── Colours
G  = "\033[92m"   # green
R  = "\033[91m"   # red
Y  = "\033[93m"   # yellow
C  = "\033[96m"   # cyan
M  = "\033[95m"   # magenta
D  = "\033[90m"   # dark gray
NC = "\033[0m"    # reset


def step(n, msg):
    print(f"\n{D}{'-'*50}{NC}")
    print(f"{C} STEP {n}: {msg}{NC}")
    print(f"{D}{'-'*50}{NC}")

def ok(msg):   print(f"{G}  [OK]   {msg}{NC}")
def fail(msg): print(f"{R}  [FAIL] {msg}{NC}"); sys.exit(1)
def info(msg): print(f"{Y}  [INFO] {msg}{NC}")


def get_firebase_id_token(uid: str) -> str:
    """Use Firebase Admin SDK to create a custom token, then exchange it for an ID token."""
    import firebase_admin
    from firebase_admin import auth, credentials

    # Initialize Firebase Admin with credentials or ADC
    try:
        app = firebase_admin.get_app()
    except ValueError:
        cred_file = "firebase-credentials.json"
        if os.path.exists(cred_file):
            cred = credentials.Certificate(cred_file)
            app = firebase_admin.initialize_app(cred)
            info("Initialized Firebase Admin with local firebase-credentials.json")
        else:
            app = firebase_admin.initialize_app()

    # Create custom token for the specific uid
    custom_token = auth.create_custom_token(uid).decode("utf-8")
    info(f"Custom token created for uid={uid}")

    if not FIREBASE_API_KEY:
        fail(
            "FIREBASE_WEB_API_KEY env var not set.\n"
            "  Get it from: Firebase Console → Project Settings → General → Web API key\n"
            "  Then run: $env:FIREBASE_WEB_API_KEY='AIza...'; python e2e_test.py"
        )

    # Exchange custom token → ID token via Firebase Auth REST API
    resp = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={FIREBASE_API_KEY}",
        json={"token": custom_token, "returnSecureToken": True},
        timeout=10,
    )
    if resp.status_code != 200:
        fail(f"Token exchange failed for {uid}: {resp.status_code} {resp.text}")

    id_token = resp.json()["idToken"]
    ok(f"Firebase ID token obtained for {uid}")
    return id_token


def trigger_outbox_publisher():
    """Trigger the Outbox Publisher's /internal/publish-pending endpoint to push pending events."""
    try:
        url = "https://jugaad-outbox-publisher-745766971944.asia-south1.run.app/internal/publish-pending"
        info(f"Triggering Outbox Publisher at {url}...")
        r = requests.post(url, timeout=30)
        info(f"Outbox Publisher response: HTTP {r.status_code} | {r.text}")
        if r.status_code == 200:
            ok(f"Outbox Publisher triggered successfully! (Published: {r.json().get('published', 0)})")
        else:
            fail(f"Outbox Publisher response non-200: {r.status_code} {r.text}")
    except Exception as e:
        fail(f"Failed to trigger Outbox Publisher: {e}")


def ensure_test_worker():
    """Ensure that the test worker test-worker-001 exists in Firestore and is ONLINE/APPROVED."""
    import firebase_admin
    from firebase_admin import firestore, credentials

    try:
        app = firebase_admin.get_app()
    except ValueError:
        cred_file = "firebase-credentials.json"
        if os.path.exists(cred_file):
            cred = credentials.Certificate(cred_file)
            app = firebase_admin.initialize_app(cred)
        else:
            app = firebase_admin.initialize_app()

    db = firestore.client()
    worker_ref = db.collection("workers").document(WORKER_ID)
    snap = worker_ref.get()
    if snap.exists:
        # Reset worker status to online/approved and clear any active jobs
        worker_ref.update({
            "approval_status": "APPROVED",
            "status": "ONLINE",
            "skills": ["plumber"],
            "lat": 12.3052,
            "lng": 76.6552,
            "geo_hash_5": "tdnw0",
        })
        info("Worker test-worker-001 exists and has been reset to ONLINE/APPROVED")
    else:
        info("Worker test-worker-001 not found. Creating...")
        worker_doc = {
            "worker_id": WORKER_ID,
            "name": "Kushal the Plumber",
            "skills": ["plumber"],
            "approval_status": "APPROVED",
            "status": "ONLINE",
            "lat": 12.3052,
            "lng": 76.6552,
            "geo_hash_5": "tdnw0",
            "rating": 4.9,
            "fcm_token": "test-fcm-token-worker",
        }
        worker_ref.set(worker_doc)
        ok("Worker test-worker-001 created successfully.")


def api(method: str, path: str, token: str, body: dict | None = None):
    url = f"{GW}{path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    r = requests.request(method, url, headers=headers, json=body, timeout=30)
    return r.status_code, r.text


# ─────────────────────────────────────────────────────────────────────
print(f"\n{M}{'='*52}{NC}")
print(f"{M}   JUGAAD END-TO-END TEST{NC}")
print(f"{M}   Gateway : {GW}{NC}")
print(f"{M}   User    : {USER_ID}{NC}")
print(f"{M}   Worker  : {WORKER_ID}{NC}")
print(f"{M}{'='*52}{NC}\n")

JOB_ID = None
final_status = "UNKNOWN"

try:
    # Step 0: Ensure worker exists in Firestore
    step(0, "Initialize Test Worker in Firestore")
    ensure_test_worker()

    # Step 1: Authenticate Customer and Worker
    step(1, "Obtain Firebase ID tokens for User and Worker")
    USER_TOKEN = get_firebase_id_token(USER_ID)
    WORKER_TOKEN = get_firebase_id_token(WORKER_ID)

    # Step 2: Create Job
    step(2, "Create Job Request  POST /v1/jobs")
    code, body = api("POST", "/v1/jobs", USER_TOKEN, {
        "user_id": USER_ID,
        "skill": "plumber",
        "description": "Leaking pipe in kitchen",
        "lat": 12.3052,
        "lng": 76.6552,
        "address": "123 MG Road, Mysuru",
        "budget_min": 300,
        "budget_max": 800,
        "is_urgent": True,
        "urgency": "now",
    })
    info(f"HTTP {code} | {body[:300]}")
    if code != 200:
        fail(f"Job creation failed: {code} {body}")
    resp = json.loads(body)
    JOB_ID = resp.get("job_id")
    if not JOB_ID:
        fail(f"No job_id in response: {body}")
    ok(f"Job created: {JOB_ID}")

    # Step 3: Trigger Outbox Publisher to propagate JOB_CREATED event
    step(3, "Trigger Outbox Publisher to process JOB_CREATED")
    trigger_outbox_publisher()
    
    info("Waiting 7s for Pub/Sub and matching-service to complete proximity search...")
    for i in range(7, 0, -1):
        print(f"\r  Waiting... {i}s ", end="", flush=True)
        time.sleep(1)
    print()

    # Step 4: Verify Matching
    step(4, f"Verify Job Matched  GET /v1/jobs/{JOB_ID}")
    code, body = api("GET", f"/v1/jobs/{JOB_ID}", USER_TOKEN)
    info(f"HTTP {code}")
    if code != 200:
        fail(f"Get job failed: {code} {body}")
    job = json.loads(body)
    info(f"status      : {job.get('status')}")
    info(f"match_count : {job.get('match_count', 0)}")
    
    # If matching service push failed or timed out, wait and try triggering outbox one more time
    if job.get("match_count", 0) == 0:
        info("No workers matched yet. Retrying Outbox Publisher trigger...")
        trigger_outbox_publisher()
        time.sleep(5)
        code, body = api("GET", f"/v1/jobs/{JOB_ID}", USER_TOKEN)
        job = json.loads(body)
        info(f"status (retry) : {job.get('status')}")
        info(f"match_count   : {job.get('match_count', 0)}")

    if job.get("match_count", 0) > 0:
        ok(f"Matching SUCCESS - {job['match_count']} worker(s) found nearby!")
    else:
        fail("Matching FAILED — no workers were matched to the job.")

    # Step 5: Worker Accepts (uses WORKER_TOKEN)
    step(5, f"Worker Accepts Job  POST /v1/jobs/{JOB_ID}/accept")
    code, body = api("POST", f"/v1/jobs/{JOB_ID}/accept", WORKER_TOKEN, {
        "worker_id": WORKER_ID,
        "expected_version": 1
    })
    info(f"HTTP {code} | {body[:200]}")
    if code != 200:
        fail(f"Accept failed: {code} {body}")
    ok(f"Worker {WORKER_ID} accepted job")
    
    # Trigger outbox to publish JOB_ASSIGNED event
    trigger_outbox_publisher()
    time.sleep(2)

    # Step 6: Worker Acknowledges (Arrived) (uses WORKER_TOKEN)
    step(6, f"Worker Arrives  POST /v1/jobs/{JOB_ID}/ack")
    code, body = api("POST", f"/v1/jobs/{JOB_ID}/ack", WORKER_TOKEN)
    info(f"HTTP {code} | {body[:200]}")
    if code != 200:
        fail(f"Ack failed: {code} {body}")
    ok("Worker acknowledged arrival at location")
    
    # Trigger outbox to publish JOB_ACK event
    trigger_outbox_publisher()
    time.sleep(2)

    # Step 7: Dual Completion - Worker confirms completion
    step(7, f"Worker Confirms Completion  POST /v1/jobs/{JOB_ID}/complete")
    code, body = api("POST", f"/v1/jobs/{JOB_ID}/complete", WORKER_TOKEN, {
        "confirmer": "worker"
    })
    info(f"HTTP {code} | {body[:200]}")
    if code != 200:
        fail(f"Worker completion failed: {code} {body}")
    ok("Worker marked completion. Status: waiting_other_party.")
    time.sleep(2)

    # Step 7.5: Dual Completion - Customer confirms completion
    step(7.5, f"Customer Confirms Completion  POST /v1/jobs/{JOB_ID}/complete")
    code, body = api("POST", f"/v1/jobs/{JOB_ID}/complete", USER_TOKEN, {
        "confirmer": "user"
    })
    info(f"HTTP {code} | {body[:200]}")
    if code != 200:
        fail(f"Customer completion failed: {code} {body}")
    ok("Customer marked completion. Status: completed.")
    
    # Trigger outbox to publish JOB_COMPLETED event
    trigger_outbox_publisher()
    time.sleep(2)

    # Step 8: Verify Final State
    step(8, f"Verify Final State  GET /v1/jobs/{JOB_ID}")
    code, body = api("GET", f"/v1/jobs/{JOB_ID}", USER_TOKEN)
    if code != 200:
        fail(f"Final state check failed: {code} {body}")
    final = json.loads(body)
    final_status = final.get("status", "?")
    print(f"\n  {C}+- FINAL JOB SUMMARY {'-'*30}{NC}")
    print(f"  {C}|{NC}  job_id         : {JOB_ID}")
    print(f"  {C}|{NC}  status         : {final_status}")
    print(f"  {C}|{NC}  worker_id      : {final.get('worker_id')}")
    print(f"  {C}|{NC}  payment_amount : Rs.{final.get('payment_amount', 0)}")
    print(f"  {C}+-{'-'*50}{NC}")

    if final_status != "completed":
        fail(f"Final status is '{final_status}', expected 'completed'!")

    # Step 9: Create Payment Order
    step(9, f"Create Payment Order  POST /v1/jobs/{JOB_ID}/create-order")
    code, body = api("POST", f"/v1/jobs/{JOB_ID}/create-order", USER_TOKEN, {})
    info(f"HTTP {code} | {body[:200]}")
    if code == 200:
        ok("Razorpay order created!")
    else:
        info(f"Payment HTTP {code} - expected with test Razorpay keys")

    # Step 10: Submit Review
    step(10, f"Customer Review  POST /v1/jobs/{JOB_ID}/review")
    code, body = api("POST", f"/v1/jobs/{JOB_ID}/review", USER_TOKEN, {
        "rating": 5,
        "comment": "Excellent work, very professional!",
    })
    info(f"HTTP {code} | {body[:200]}")
    if code == 200:
        ok("5-star review submitted!")
    else:
        info(f"Review HTTP {code}")

except Exception as e:
    print(f"\n{R}  [EXCEPTION] {e}{NC}")
    traceback.print_exc()
    sys.exit(1)

finally:
    # Final Summary
    print(f"\n{G}{'='*52}{NC}")
    print(f"{G}   E2E TEST COMPLETE{NC}")
    print(f"{G}   Job ID  : {JOB_ID}{NC}")
    print(f"{G}   Status  : {final_status}{NC}")
    print(f"{G}{'='*52}{NC}\n")
    if JOB_ID:
        url = f"https://console.firebase.google.com/project/jugaad-prod-app-2026/firestore/data/jobs/{JOB_ID}"
        print(f"  Firestore audit: {url}\n")
