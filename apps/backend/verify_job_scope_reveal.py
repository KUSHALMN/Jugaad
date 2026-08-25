import os
import sys
import uuid
import logging
from datetime import datetime, timezone
from dotenv import load_dotenv

logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

load_dotenv(".env.local")
if not os.getenv("SUPABASE_URL"):
    load_dotenv(".env")

from fastapi.testclient import TestClient
from main import app
from shared.database import supabase

client = TestClient(app)

print("=================================================================")
print("  EMPIRICAL VERIFICATION AUDIT FOR JOB-SCOPED PHONE REVEAL (5 CHECKS)")
print("=================================================================\n")

run_digits = ''.join([c for c in str(uuid.uuid4().int) if c.isdigit()])[:6]

EMPLOYER_ID = f"emp_scope_{run_digits}"
EMPLOYER_PHONE_RAW = f"98{run_digits}11"[:10]
EMPLOYER_PHONE_FULL = f"+91{EMPLOYER_PHONE_RAW}"

WORKER_ID = f"worker_scope_{run_digits}"
WORKER_PHONE_RAW = f"97{run_digits}22"[:10]
WORKER_PHONE_FULL = f"+91{WORKER_PHONE_RAW}"

THIRD_PARTY_ID = f"third_party_{run_digits}"
THIRD_PARTY_PHONE_FULL = f"+9196{run_digits}33"[:13]

def setup_users():
    # Insert Employer
    supabase.table("users").insert({
        "id": EMPLOYER_ID,
        "firebase_uid": EMPLOYER_ID,
        "name": "Employer Scope Test",
        "phone": EMPLOYER_PHONE_FULL,
        "email": f"emp_{run_digits}@test.com",
        "role": "employer"
    }).execute()

    # Insert Worker
    supabase.table("users").insert({
        "id": WORKER_ID,
        "firebase_uid": WORKER_ID,
        "name": "Worker Scope Test",
        "phone": WORKER_PHONE_FULL,
        "email": f"worker_{run_digits}@test.com",
        "role": "worker"
    }).execute()
    supabase.table("workers").insert({
        "id": WORKER_ID,
        "worker_id": WORKER_ID,
        "name": "Worker Scope Test",
        "phone": WORKER_PHONE_RAW,
        "skills": ["electrician"],
        "status": "approved",
        "approval_status": "approved",
        "is_available": True
    }).execute()

    # Insert Third Party User
    supabase.table("users").insert({
        "id": THIRD_PARTY_ID,
        "firebase_uid": THIRD_PARTY_ID,
        "name": "Unrelated User",
        "phone": THIRD_PARTY_PHONE_FULL,
        "email": f"third_{run_digits}@test.com",
        "role": "employer"
    }).execute()

def cleanup():
    try:
        supabase.table("jobs").delete().in_("employer_id", [EMPLOYER_ID, THIRD_PARTY_ID]).execute()
        supabase.table("workers").delete().eq("id", WORKER_ID).execute()
        supabase.table("users").delete().in_("id", [EMPLOYER_ID, WORKER_ID, THIRD_PARTY_ID]).execute()
    except Exception as e:
        print(f"[CLEANUP] {e}")

setup_users()

# Create 2 test jobs: one open, one accepted
JOB_OPEN_ID = str(uuid.uuid4())
JOB_ACCEPTED_ID = str(uuid.uuid4())
now_iso = datetime.now(timezone.utc).isoformat()

supabase.table("jobs").insert({
    "id": JOB_OPEN_ID,
    "employer_id": EMPLOYER_ID,
    "status": "open",
    "skill_required": "electrician",
    "amount": 250.0,
    "created_at": now_iso
}).execute()

supabase.table("jobs").insert({
    "id": JOB_ACCEPTED_ID,
    "employer_id": EMPLOYER_ID,
    "worker_id": WORKER_ID,
    "status": "accepted",
    "skill_required": "electrician",
    "amount": 300.0,
    "accepted_at": now_iso,
    "created_at": now_iso
}).execute()

from main import app
from shared.auth import verify_firebase_token

# Helper mock for auth token dependency
def get_auth_headers(uid: str):
    return {"Authorization": f"Bearer mock_token_{uid}"}

# Override auth dependency for TestClient
app.dependency_overrides[verify_firebase_token] = lambda req=None, authorization=None: None

# -----------------------------------------------------------------
# CHECK 1: GET /api/v1/jobs/{job_id} for ACCEPTED job as EMPLOYER
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("CHECK 1: GET /api/v1/jobs/{job_id} for ACCEPTED job as EMPLOYER")
print("-----------------------------------------------------------------")

app.dependency_overrides[verify_firebase_token] = lambda: EMPLOYER_ID
res1 = client.get(f"/api/v1/jobs/{JOB_ACCEPTED_ID}")
json1 = res1.json()

print(f"Employer GET Accepted Job Response Status: {res1.status_code}")
print("Raw JSON Response:")
print(json1)

check1_has_raw_phone = json1.get("worker_phone") == WORKER_PHONE_FULL or json1.get("worker_phone") == WORKER_PHONE_RAW
print(f" -> Raw Worker Phone present for employer: {check1_has_raw_phone} ('{json1.get('worker_phone')}')")
check1_pass = res1.status_code == 200 and check1_has_raw_phone
print(f">>> CHECK 1 RESULT: {'PASS' if check1_pass else 'FAIL'}\n")

# -----------------------------------------------------------------
# CHECK 2: GET /api/v1/jobs/{job_id} for OPEN job as EMPLOYER
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("CHECK 2: GET /api/v1/jobs/{job_id} for OPEN/REQUESTED job as EMPLOYER")
print("-----------------------------------------------------------------")

res2 = client.get(f"/api/v1/jobs/{JOB_OPEN_ID}")
json2 = res2.json()

print(f"Employer GET Open Job Response Status: {res2.status_code}")
print("Raw JSON Response:")
print(json2)

check2_raw_phone_absent = "worker_phone" not in json2 or not json2.get("worker_phone")
print(f" -> Raw Worker Phone absent for open job: {check2_raw_phone_absent} (Value: {json2.get('worker_phone')})")
check2_pass = res2.status_code == 200 and check2_raw_phone_absent
print(f">>> CHECK 2 RESULT: {'PASS' if check2_pass else 'FAIL'}\n")

# -----------------------------------------------------------------
# CHECK 3: GET /api/v1/jobs/{job_id} as UNRELATED THIRD-PARTY USER
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("CHECK 3: GET /api/v1/jobs/{job_id} as UNRELATED THIRD-PARTY USER")
print("-----------------------------------------------------------------")

app.dependency_overrides[verify_firebase_token] = lambda: THIRD_PARTY_ID
res3 = client.get(f"/api/v1/jobs/{JOB_ACCEPTED_ID}")
json3 = res3.json()

print(f"Third Party GET Accepted Job Response Status: {res3.status_code} (Expected: 403)")
print("Raw JSON Error Response:")
print(json3)

check3_pass = res3.status_code == 403
print(f" -> Access Rejected (403 Forbidden): {check3_pass}")
print(f">>> CHECK 3 RESULT: {'PASS' if check3_pass else 'FAIL'}\n")

# -----------------------------------------------------------------
# CHECK 4: GET /api/v1/jobs/{job_id} for ACCEPTED job as WORKER
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("CHECK 4: GET /api/v1/jobs/{job_id} for ACCEPTED job as WORKER")
print("-----------------------------------------------------------------")

app.dependency_overrides[verify_firebase_token] = lambda: WORKER_ID
res4 = client.get(f"/api/v1/jobs/{JOB_ACCEPTED_ID}")
json4 = res4.json()

print(f"Worker GET Accepted Job Response Status: {res4.status_code}")
print("Raw JSON Response:")
print(json4)

check4_has_emp_phone = json4.get("customer_phone") == EMPLOYER_PHONE_FULL or json4.get("employer_phone") == EMPLOYER_PHONE_FULL
print(f" -> Employer/Customer Raw Phone present for worker: {check4_has_emp_phone} ('{json4.get('customer_phone') or json4.get('employer_phone')}')")
check4_pass = res4.status_code == 200 and check4_has_emp_phone
print(f">>> CHECK 4 RESULT: {'PASS' if check4_pass else 'FAIL'}\n")

# Cleanup after tests
app.dependency_overrides.clear()
cleanup()

print("=================================================================")
print("SUMMARY OF 4 API SCOPE CHECKS:")
print("=================================================================")
print(f"Check 1 (Accepted Job Employer View Raw Phone): {'PASS' if check1_pass else 'FAIL'}")
print(f"Check 2 (Open Job Raw Phone Absent): {'PASS' if check2_pass else 'FAIL'}")
print(f"Check 3 (Third-Party 403 Forbidden): {'PASS' if check3_pass else 'FAIL'}")
print(f"Check 4 (Accepted Job Worker View Employer Phone): {'PASS' if check4_pass else 'FAIL'}")
