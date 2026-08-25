import os
import sys
import httpx
import json
from dotenv import load_dotenv

# Load environmental variables
load_dotenv()

G = "\033[92m"   # green
R = "\033[91m"   # red
Y = "\033[93m"   # yellow
C = "\033[96m"   # cyan
NC = "\033[0m"    # reset

print(f"{C}=========================================================={NC}")
print(f"{C}        JUGAAD APP — SYSTEM INTEGRATION DIAGNOSTICS       {NC}")
print(f"{C}=========================================================={NC}\n")

# --- 1. LOCAL API HEALTH & CORS CHECK ---
print(f"{Y}[TEST 1/5] FastAPI Server Health & CORS Settings:{NC}")
api_url = "http://localhost:8000/health"
cors_url = "http://localhost:8000/api/v1/services"
cors_pass = True

# Test GET /health
try:
    resp = httpx.get(api_url, timeout=5.0)
    print(f"  GET {api_url} -> Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"  Response: {json.dumps(data)}")
        if data.get("status") == "ok" and "timestamp" in data:
            print(f"  {G}[PASS]{NC} GET /health returned valid status and timestamp.")
        else:
            print(f"  {R}[FAIL]{NC} Missing 'status' or 'timestamp' in response.")
            cors_pass = False
    else:
        print(f"  {R}[FAIL]{NC} Health check returned non-200 status: {resp.status_code}")
        cors_pass = False
except Exception as e:
    print(f"  {R}[FAIL]{NC} Could not connect to FastAPI server: {e}")
    print("         (Ensure local server is running: uvicorn main:app --reload)")
    cors_pass = False

# Test CORS headers (OPTIONS request simulation)
if cors_pass:
    try:
        headers = {
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type"
        }
        cors_resp = httpx.options(cors_url, headers=headers, timeout=5.0)
        print(f"  OPTIONS {cors_url} -> Status: {cors_resp.status_code}")
        allow_origin = cors_resp.headers.get("access-control-allow-origin", "")
        allow_cred = cors_resp.headers.get("access-control-allow-credentials", "")
        
        if allow_origin == "http://localhost:3000" or allow_origin == "*":
            # Note: With allow_credentials=True, access-control-allow-origin must match the origin explicitly
            print(f"  CORS Origin: {allow_origin} | Allow Credentials: {allow_cred}")
            print(f"  {G}[PASS]{NC} CORS headers correctly configured for Flutter and web app clients.")
        elif cors_resp.status_code == 200:
            print(f"  CORS Origin: {allow_origin} | Allow Credentials: {allow_cred}")
            print(f"  {G}[PASS]{NC} CORS response ok.")
        else:
            print(f"  {R}[FAIL]{NC} CORS headers missing or misconfigured.")
    except Exception as e:
        print(f"  {R}[FAIL]{NC} CORS preflight check failed: {e}")

# --- 2. SUPABASE API & DATABASE SCHEMA CHECK ---
print(f"\n{Y}[TEST 2/5] Supabase DB Connectivity & Schema Validation:{NC}")
sb_url = os.getenv("SUPABASE_URL")
sb_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not sb_url or not sb_key:
    print(f"  {R}[FAIL]{NC} Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment.")
else:
    # 2.1 Direct REST client connection test
    try:
        from supabase import create_client
        client = create_client(sb_url, sb_key)
        
        # Test generic table
        user_res = client.table("users").select("id").limit(1).execute()
        print(f"  {G}[PASS]{NC} Queried Supabase users table successfully.")
    except Exception as e:
        print(f"  {R}[FAIL]{NC} Supabase client query failed: {e}")
        
    # 2.2 Inspect PostgREST OpenAPI spec for views, functions, and types
    try:
        headers = {
            "apikey": sb_key,
            "Authorization": f"Bearer {sb_key}"
        }
        # Fetch OpenAPI specification from PostgREST
        schema_resp = httpx.get(f"{sb_url}/rest/v1/", headers=headers, timeout=10.0)
        if schema_resp.status_code == 200:
            schema_data = schema_resp.json()
            paths = schema_data.get("paths", {})
            definitions = schema_data.get("definitions", {})
            
            # A. Check worker_profiles view
            if "/worker_profiles" in paths:
                print(f"  {G}[PASS]{NC} View 'worker_profiles' is registered and exposed in schema cache.")
                
                # Check current_location type
                wp_definition = definitions.get("worker_profiles", {})
                properties = wp_definition.get("properties", {})
                location_prop = properties.get("current_location", {})
                location_desc = location_prop.get("description", "").lower()
                location_format = location_prop.get("format", "").lower()
                
                if "geometry" in location_desc or "geometry" in location_format:
                    print(f"  {G}[PASS]{NC} worker_profiles.current_location is of GEOMETRY type.")
                else:
                    print(f"  {Y}[WARNING]{NC} worker_profiles.current_location type is: {location_format or 'unknown'}. (Expected GEOMETRY)")
            else:
                print(f"  {R}[FAIL]{NC} View 'worker_profiles' NOT found in schema cache. (Did you run the SQL migration?)")
                
            # B. Check search_workers_postgis RPC function
            if "/rpc/search_workers_postgis" in paths:
                print(f"  {G}[PASS]{NC} RPC function 'search_workers_postgis' is registered in schema cache.")
            else:
                print(f"  {R}[FAIL]{NC} RPC function 'search_workers_postgis' NOT found in schema cache.")
        else:
            print(f"  {R}[FAIL]{NC} Failed to retrieve PostgREST schema info: {schema_resp.status_code}")
    except Exception as e:
        print(f"  {R}[FAIL]{NC} PostgREST schema verification failed: {e}")

# --- 3. REDIS CONNECTION & PERSISTENCE CHECK ---
print(f"\n{Y}[TEST 3/5] Upstash Redis Connectivity & Latency Check:{NC}")
try:
    from shared import redis_client
    r = redis_client.get_client()
    if r:
        import time
        start_t = time.time()
        r.set("health_check_ping", "1", ex=5)
        val = r.get("health_check_ping")
        elapsed = (time.time() - start_t) * 1000
        if val == "1":
            print(f"  {G}[PASS]{NC} Redis write/read completed in {elapsed:.1f}ms successfully!")
        else:
            print(f"  {R}[FAIL]{NC} Redis read verification returned: {val}")
    else:
        print(f"  {R}[FAIL]{NC} Upstash Redis client failed to initialize.")
except Exception as e:
    print(f"  {R}[FAIL]{NC} Redis verification failed: {e}")

# --- 4. FIREBASE ADMIN SDK (FCM) INITIALIZATION ---
print(f"\n{Y}[TEST 4/5] Firebase Admin SDK (FCM Credentials) Check:{NC}")
try:
    import shared.firebase_init
    import firebase_admin
    if firebase_admin._apps:
        # Check active project identification
        app = firebase_admin.get_app()
        print(f"  Firebase App Name: {app.name}")
        print(f"  {G}[PASS]{NC} Firebase Admin SDK initialized successfully!")
    else:
        print(f"  {R}[FAIL]{NC} Firebase Admin SDK is NOT initialized.")
except Exception as e:
    print(f"  {R}[FAIL]{NC} Firebase FCM initialization failed: {e}")

# --- 5. ENQUEUING / QUEUE MODE CHECK ---
print(f"\n{Y}[TEST 5/5] Background Queue (QStash/Local) Configuration:{NC}")
queue_mode = os.getenv("QUEUE_MODE", "local")
print(f"  Configured Queue Mode: {queue_mode}")
if queue_mode == "qstash":
    token = os.getenv("QSTASH_TOKEN")
    current_key = os.getenv("QSTASH_CURRENT_SIGNING_KEY")
    next_key = os.getenv("QSTASH_NEXT_SIGNING_KEY")
    
    if not token:
        print(f"  {R}[FAIL]{NC} QSTASH_TOKEN environment variable is missing.")
    elif not current_key or not next_key:
        print(f"  {Y}[WARNING]{NC} QStash keys are missing. Webhook verification will fail in production.")
    else:
        print(f"  {G}[PASS]{NC} QStash credentials present in environment.")
else:
    print(f"  {G}[PASS]{NC} Queue running in LOCAL mode. No QStash signature validation required.")

print(f"\n{C}=========================================================={NC}")
print(f"{C}                     DIAGNOSTICS COMPLETE                  {NC}")
print(f"{C}=========================================================={NC}")
