import os
import sys
import httpx
import json
from dotenv import load_dotenv

load_dotenv()

print("==========================================================")
print("JUGAAD APP — INTEGRATION & HEALTH VERIFICATION TEST")
print("==========================================================\n")

# --- 1. LOCAL API HEALTH CHECK
print("[TEST 1/5] API Health Check:")
api_url = "http://localhost:8000/health"
try:
    resp = httpx.get(api_url, timeout=5.0)
    print(f"  GET {api_url} -> Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"  Response: {json.dumps(data)}")
        if data.get("status") == "ok" and "timestamp" in data:
            print("  [PASS] API Health Check Passed successfully!")
        else:
            print("  [FAIL] Missing 'status' or 'timestamp' in response.")
    else:
        print(f"  [FAIL] Health check failed with status: {resp.status_code}")
except Exception as e:
    print(f"  [FAIL] Could not connect to API server: {e}")
    print("         (Make sure your FastAPI server is running local: uvicorn main:app --reload)")

# --- 2. SUPABASE CONNECTION & SCHEMA CHECK
print("\n[TEST 2/5] Supabase DB Connectivity & Schema:")
sb_url = os.getenv("SUPABASE_URL")
sb_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not sb_url or not sb_key:
    print("  [FAIL] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in env.")
else:
    try:
        from supabase import create_client
        client = create_client(sb_url, sb_key)
        
        # Test generic table
        user_res = client.table("users").select("id").limit(1).execute()
        print("  [PASS] Successfully queried Supabase users table.")
        
        # Test worker_profiles view
        try:
            view_res = client.table("worker_profiles").select("*").limit(1).execute()
            print("  [PASS] Successfully queried 'worker_profiles' view!")
        except Exception as view_err:
            print(f"  [FAIL] 'worker_profiles' view query failed. (Did you run the SQL migration?): {view_err}")
            
        # Test PostGIS function
        try:
            rpc_res = client.rpc("search_workers_postgis", {
                "lat": 12.2905,
                "lng": 76.6277,
                "radius_km": 5.0,
                "service_type": "electrician",
                "page": 0,
                "limit": 5
            }).execute()
            print("  [PASS] Successfully executed search_workers_postgis RPC function!")
        except Exception as rpc_err:
            print(f"  [FAIL] search_workers_postgis RPC execution failed: {rpc_err}")
            
    except Exception as e:
        print(f"  [FAIL] Supabase client connectivity failed: {e}")

# --- 3. REDIS CONNECTIVITY
print("\n[TEST 3/5] Redis Connectivity:")
try:
    from shared import redis_client
    r = redis_client.get_client()
    if r:
        r.set("integration_test_key", "active", ex=5)
        val = r.get("integration_test_key")
        if val == "active":
            print("  [PASS] Redis write/read verified successfully!")
        else:
            print(f"  [FAIL] Redis returned unexpected value: {val}")
    else:
        print("  [FAIL] Redis client unavailable.")
except Exception as e:
    print(f"  [FAIL] Redis verification failed: {e}")

# --- 4. FIREBASE ADMIN SDK (FCM) CREDENTIALS
print("\n[TEST 4/5] Firebase FCM Initialization:")
try:
    import shared.firebase_init
    import firebase_admin
    if firebase_admin._apps:
        print("  [PASS] Firebase Admin SDK initialized successfully!")
    else:
        print("  [FAIL] Firebase Admin SDK is NOT initialized.")
except Exception as e:
    print(f"  [FAIL] Firebase initialization failed: {e}")

# --- 5. QSTASH CONFIGURATION
print("\n[TEST 5/5] QStash Queue Configuration:")
queue_mode = os.getenv("QUEUE_MODE", "local")
print(f"  Active Queue Mode: {queue_mode}")
if queue_mode == "qstash":
    token = os.getenv("QSTASH_TOKEN")
    if token:
        print("  [PASS] QStash token is set in environment.")
    else:
        print("  [FAIL] QUEUE_MODE is qstash but QSTASH_TOKEN is missing.")
else:
    print("  [PASS] Running in LOCAL mode queue (no cloud QStash token required).")

print("\n==========================================================")
print("TEST COMPLETED")
print("==========================================================")
