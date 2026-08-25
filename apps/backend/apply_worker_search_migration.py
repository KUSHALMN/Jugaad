import os
import httpx
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_SERVICE_KEY")

# Read the SQL migration file
migration_path = os.path.join(os.path.dirname(__file__), "supabase", "worker_search_migration.sql")
with open(migration_path, "r", encoding="utf-8") as f:
    sql = f.read()

project_ref = SUPABASE_URL.replace("https://", "").replace(".supabase.co", "")
print(f"Project ref: {project_ref}")

headers = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

# Attempt various Supabase SQL execution endpoints
endpoints_to_try = [
    # The newer Supabase SQL HTTP API
    (f"{SUPABASE_URL}/rest/v1/rpc/exec_sql", {"sql": sql}),
    # pg-meta query endpoint  
    (f"{SUPABASE_URL}/pg/query", {"query": sql}),
    # Supabase internal SQL endpoint
    (f"{SUPABASE_URL}/sql", {"query": sql}),
]

success = False
for url, payload in endpoints_to_try:
    print(f"\nTrying: {url}")
    try:
        response = httpx.post(url, headers=headers, json=payload, timeout=30.0)
        print(f"  Status: {response.status_code}")
        print(f"  Response: {response.text[:300]}")
        if response.status_code in (200, 201):
            success = True
            print("  SUCCESS!")
            break
    except Exception as e:
        print(f"  Error: {e}")

if not success:
    print("\nAll HTTP endpoints failed.")
    print("Attempting to create via Supabase Python SDK rpc...")
    
    try:
        from supabase import create_client
        sb = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        result = sb.rpc("exec_sql", {"sql": sql}).execute()
        print(f"rpc exec_sql result: {result}")
        success = True
    except Exception as e:
        print(f"rpc exec_sql failed: {e}")

if not success:
    print("\n" + "=" * 60)
    print("MANUAL STEP REQUIRED")
    print("=" * 60)
    print(f"Please run the SQL in the Supabase SQL Editor:")
    print(f"  https://supabase.com/dashboard/project/{project_ref}/sql/new")
    print(f"  Copy contents from: supabase/worker_search_migration.sql")
    print("=" * 60)
