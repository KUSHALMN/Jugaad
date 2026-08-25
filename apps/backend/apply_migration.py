"""
Apply the services_migration.sql to Supabase using the SQL HTTP API.
Supabase exposes a /pg/ endpoint for SQL execution (available to service role).
"""
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")

# Read the SQL migration file
migration_path = os.path.join(os.path.dirname(__file__), "supabase", "services_migration.sql")
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
    # Last resort: try to use supabase-py's rpc to call a function that can run SQL
    # Some Supabase projects have exec_sql or similar admin functions
    print("\nAll HTTP endpoints failed.")
    print("Attempting to create table via Supabase Python SDK rpc...")
    
    from supabase import create_client
    sb = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    
    try:
        # Some Supabase instances have extensions/functions for SQL
        result = sb.rpc("exec_sql", {"sql": sql}).execute()
        print(f"rpc exec_sql result: {result}")
        success = True
    except Exception as e:
        print(f"rpc exec_sql failed: {e}")
    
    if not success:
        # Try pgcrypto or other extensions
        try:
            # Try creating via the SQL function approach
            # First try to see if we can call any admin function
            result = sb.rpc("information_schema.tables", {}).execute()
            print(f"info result: {result}")
        except Exception as e:
            print(f"info failed: {e}")

if not success:
    print("\n" + "=" * 60)
    print("MANUAL STEP REQUIRED")
    print("=" * 60)
    print(f"Please run the SQL in the Supabase SQL Editor:")
    print(f"  https://supabase.com/dashboard/project/{project_ref}/sql/new")
    print(f"  Copy contents from: supabase/services_migration.sql")
    print("=" * 60)
