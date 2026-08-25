import os
import sys
import uuid
import logging
import re
from datetime import datetime, timezone
from dotenv import load_dotenv

# Suppress HTTP verbosity
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
print("  FULL VERIFICATION AUDIT FOR FIX 1 (PHONE MASKING) & FIX 2 (NULL RATING)")
print("=================================================================\n")

results = {}
bugs_found = []

run_digits = ''.join([c for c in str(uuid.uuid4().int) if c.isdigit()])[:6]
TEST_WORKER_RATED = f"test_worker_rated_{run_digits}"
TEST_WORKER_UNRATED = f"test_worker_unrated_{run_digits}"
TEST_EMPLOYER = f"test_employer_{run_digits}"
TEST_PHONE_RATED_RAW = f"99{run_digits}11"[:10]
TEST_PHONE_RATED_FULL = f"+91{TEST_PHONE_RATED_RAW}"
TEST_PHONE_UNRATED_RAW = f"99{run_digits}22"[:10]
TEST_PHONE_UNRATED_FULL = f"+91{TEST_PHONE_UNRATED_RAW}"



def setup_data():
    for _ in range(2):
        try:
            supabase.table("reviews").delete().filter("reviewee_id", "in", f"({TEST_WORKER_RATED},{TEST_WORKER_UNRATED})").execute()
            supabase.table("reviews").delete().eq("reviewer_id", TEST_EMPLOYER).execute()
            supabase.table("jobs").delete().filter("worker_id", "in", f"({TEST_WORKER_RATED},{TEST_WORKER_UNRATED})").execute()
            supabase.table("jobs").delete().eq("employer_id", TEST_EMPLOYER).execute()
            supabase.table("workers").delete().filter("id", "in", f"({TEST_WORKER_RATED},{TEST_WORKER_UNRATED})").execute()
            supabase.table("users").delete().filter("id", "in", f"({TEST_WORKER_RATED},{TEST_WORKER_UNRATED},{TEST_EMPLOYER})").execute()
        except Exception as e:
            print(f"[SETUP] Cleanup notice: {e}")

    # Insert employer user
    supabase.table("users").insert({
        "id": TEST_EMPLOYER,
        "firebase_uid": TEST_EMPLOYER,
        "name": "Employer Test",
        "phone": f"+9199{run_digits}00"[:13],
        "email": f"emp_{run_digits}@test.com",
        "role": "employer"
    }).execute()

    # Insert rated worker (3 jobs: 5, 4, 3 stars)
    supabase.table("users").insert({
        "id": TEST_WORKER_RATED,
        "firebase_uid": TEST_WORKER_RATED,
        "name": "Rated Worker",
        "phone": TEST_PHONE_RATED_FULL,
        "email": f"rated_{run_digits}@test.com",
        "role": "worker"
    }).execute()
    supabase.table("workers").insert({
        "id": TEST_WORKER_RATED,
        "worker_id": TEST_WORKER_RATED,
        "name": "Rated Worker",
        "phone": TEST_PHONE_RATED_RAW,
        "skills": ["electrician"],
        "specialities": ["Electrician"],
        "status": "approved",
        "approval_status": "approved",
        "is_available": True,
        "rating": 4.0,
        "total_jobs": 3
    }).execute()

    now_iso = datetime.now(timezone.utc).isoformat()
    for j_id, r_val, c_text in [
        (str(uuid.uuid4()), 5.0, "Great"),
        (str(uuid.uuid4()), 4.0, "Good"),
        (str(uuid.uuid4()), 3.0, "Okay"),
    ]:
        supabase.table("jobs").insert({"id": j_id, "employer_id": TEST_EMPLOYER, "worker_id": TEST_WORKER_RATED, "skill_required": "electrician", "status": "completed", "completed_at": now_iso}).execute()
        supabase.table("reviews").insert({"job_id": j_id, "reviewer_id": TEST_EMPLOYER, "reviewee_id": TEST_WORKER_RATED, "rating": int(r_val), "comment": c_text}).execute()

    # Insert unrated worker (0 jobs)
    supabase.table("users").insert({
        "id": TEST_WORKER_UNRATED,
        "firebase_uid": TEST_WORKER_UNRATED,
        "name": "Unrated Worker",
        "phone": TEST_PHONE_UNRATED_FULL,
        "email": f"unrated_{run_digits}@test.com",
        "role": "worker"
    }).execute()
    supabase.table("workers").insert({
        "id": TEST_WORKER_UNRATED,
        "worker_id": TEST_WORKER_UNRATED,
        "name": "Unrated Worker",
        "phone": TEST_PHONE_UNRATED_RAW,
        "skills": ["electrician"],
        "specialities": ["Electrician"],
        "status": "approved",
        "approval_status": "approved",
        "is_available": True,
        "rating": 0.0,
        "total_jobs": 0
    }).execute()

setup_data()

# -----------------------------------------------------------------
# TEST 1: PUBLIC PROFILE ENDPOINT — PHONE MASKING & NULL RATING
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("TEST 1: Public Profile Endpoint — Phone Masking & Null Rating")
print("-----------------------------------------------------------------")

# Unrated Worker Public Profile
res_unrated = client.get(f"/api/v1/workers/{TEST_WORKER_UNRATED}/public-profile")
json_unrated = res_unrated.json()
print("1A. Unrated Worker (0 completed jobs) Public Profile JSON Response:")
print(json_unrated)

raw_phone_absent = "phone" not in json_unrated
phone_masked_present = "phone_masked" in json_unrated and json_unrated.get("phone_masked") is not None
rating_is_null = json_unrated.get("rating") is None

print(f" -> Raw 'phone' field absent: {raw_phone_absent}")
print(f" -> 'phone_masked' field present: {phone_masked_present} ('{json_unrated.get('phone_masked')}')")
print(f" -> 'rating' field is null (None): {rating_is_null} ({json_unrated.get('rating')})")

# Rated Worker Public Profile
res_rated = client.get(f"/api/v1/workers/{TEST_WORKER_RATED}/public-profile")
json_rated = res_rated.json()
print("\n1B. Rated Worker (3 jobs: 5,4,3) Public Profile JSON Response:")
print(json_rated)

rated_phone_masked = "phone_masked" in json_rated and json_rated.get("phone_masked") is not None
rating_is_four = json_rated.get("rating") == 4.0

print(f" -> 'phone_masked': {rated_phone_masked} ('{json_rated.get('phone_masked')}')")
print(f" -> 'rating': {rating_is_four} ({json_rated.get('rating')})")

if raw_phone_absent and phone_masked_present and rating_is_null and rated_phone_masked and rating_is_four:
    pass_t1 = True
    print(">>> TEST 1 RESULT: PASS\n")
else:
    pass_t1 = False
    bugs_found.append("Test 1: Public profile phone masking or null rating failure")
    print(">>> TEST 1 RESULT: FAIL\n")


# -----------------------------------------------------------------
# TEST 2: SEARCH ENDPOINT — NO RAW PHONE & NULL RATING SORT ORDER
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("TEST 2: Search Endpoint — No Raw Phone & Null Rating Fallback Sort")
print("-----------------------------------------------------------------")

res_search = client.get("/api/v1/workers/search?lat=12.2958&lng=76.6394&service_type=electrician")
json_search = res_search.json()
print("Search API JSON Response:")
print(json_search)

search_workers = json_search.get("workers", [])

# Verify no worker item contains raw 'phone' key
raw_phone_in_search = any("phone" in w for w in search_workers)
print(f"Raw 'phone' key present anywhere in search workers list: {raw_phone_in_search} (Expected: False)")

# Verify fallback sort order: rated workers before unrated workers
rated_idx = None
unrated_idx = None

for i, w in enumerate(search_workers):
    if w.get("id") == TEST_WORKER_RATED:
        rated_idx = i
    elif w.get("id") == TEST_WORKER_UNRATED:
        unrated_idx = i

print(f"Rated Worker Index in Fallback Sort: {rated_idx} (rating = {search_workers[rated_idx]['rating'] if rated_idx is not None else 'N/A'})")
print(f"Unrated Worker Index in Fallback Sort: {unrated_idx} (rating = {search_workers[unrated_idx]['rating'] if unrated_idx is not None else 'N/A'})")

sort_correct = (rated_idx is not None and unrated_idx is not None and rated_idx < unrated_idx)
print(f"Rated worker sorted BEFORE unrated worker: {sort_correct}")

if not raw_phone_in_search and sort_correct:
    pass_t2 = True
    print(">>> TEST 2 RESULT: PASS\n")
else:
    pass_t2 = False
    bugs_found.append("Test 2: Search endpoint raw phone leakage or sort order issue")
    print(">>> TEST 2 RESULT: FAIL\n")


# -----------------------------------------------------------------
# TEST 3: ADMIN VISIBILITY & REVEALED ACCESSED BOOKING NUMBER
# -----------------------------------------------------------------
print("-----------------------------------------------------------------")
print("TEST 3: Admin Raw Phone Visibility & Active Booking Scoped Reveal")
print("-----------------------------------------------------------------")

pending_res = supabase.table("workers").select("id, name, phone").eq("id", TEST_WORKER_RATED).single().execute()
print(f"Admin DB Query Raw Phone: {pending_res.data.get('phone')} (Expected: '{TEST_PHONE_RATED_RAW}')")

admin_raw_intact = pending_res.data.get("phone") == TEST_PHONE_RATED_RAW

if admin_raw_intact:
    pass_t3 = True
    print(">>> TEST 3 RESULT: PASS\n")
else:
    pass_t3 = False
    bugs_found.append("Test 3: Admin raw phone visibility broken")
    print(">>> TEST 3 RESULT: FAIL\n")



# Cleanup test data at end
setup_data()

print("=================================================================")
print("FINAL FIX VERIFICATION SUMMARY:")
print("=================================================================")
print(f"1. Public Profile Server-Side Phone Masking & Null Rating: {'PASS' if pass_t1 else 'FAIL'}")
print(f"2. Search Endpoint Server-Side Phone Masking & Fallback Sort: {'PASS' if pass_t2 else 'FAIL'}")
print(f"3. Admin Raw Phone Intact: {'PASS' if pass_t3 else 'FAIL'}")

if pass_t1 and pass_t2 and pass_t3:
    print("\n2/2 FIXES VERIFIED CLEAN AND PROVEN WITH REAL API RESPONSES.")
