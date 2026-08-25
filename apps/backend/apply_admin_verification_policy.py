import os
import httpx
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")

migration_path = os.path.join(os.path.dirname(__file__), "supabase", "admin_verification_policy.sql")
with open(migration_path, "r", encoding="utf-8") as f:
    sql = f.read()

project_ref = SUPABASE_URL.replace("https://", "").replace(".supabase.co", "")
print(f"Project ref: {project_ref}")

headers = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

endpoints_to_try = [
    (f"{SUPABASE_URL}/rest/v1/rpc/exec_sql", {"sql": sql}),
    (f"{SUPABASE_URL}/pg/query", {"query": sql}),
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
    from supabase import create_client
    sb = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    try:
        result = sb.rpc("exec_sql", {"sql": sql}).execute()
        print(f"rpc exec_sql result: {result}")
        success = True
    except Exception as e:
        print(f"rpc exec_sql failed: {e}")

if success:
    print("\nSuccessfully applied admin verification RLS policy to Supabase Storage!")
else:
    print("\nCould not automatically apply RLS policy. Please apply manual_verification_policy.sql in Supabase SQL editor.")
