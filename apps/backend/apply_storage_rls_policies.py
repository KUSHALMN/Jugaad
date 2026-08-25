import os
import httpx
from dotenv import load_dotenv

load_dotenv(".env.local")
load_dotenv(".env")

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not url or not key:
    print("ERROR: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")
    exit(1)

project_ref = url.replace("https://", "").replace(".supabase.co", "")

sql = """
-- Enable public uploads for worker storage buckets
DROP POLICY IF EXISTS "Public Read worker buckets" ON storage.objects;
CREATE POLICY "Public Read worker buckets" ON storage.objects
  FOR SELECT TO public USING (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));

DROP POLICY IF EXISTS "Public Upload worker buckets" ON storage.objects;
CREATE POLICY "Public Upload worker buckets" ON storage.objects
  FOR INSERT TO public WITH CHECK (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));

DROP POLICY IF EXISTS "Public Update worker buckets" ON storage.objects;
CREATE POLICY "Public Update worker buckets" ON storage.objects
  FOR UPDATE TO public USING (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));
"""

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json",
}

print(f"Applying Storage RLS Policies to Supabase Project '{project_ref}'...")

# Try various endpoints
endpoints = [
    (f"{url}/rest/v1/rpc/exec_sql", {"sql": sql}),
    (f"{url}/pg/query", {"query": sql}),
    (f"{url}/sql", {"query": sql}),
]

applied = False
for ep, payload in endpoints:
    try:
        r = httpx.post(ep, headers=headers, json=payload, timeout=15)
        if r.status_code in (200, 201):
            print(f"SUCCESS via {ep}")
            applied = True
            break
        else:
            print(f"Endpoint {ep} returned {r.status_code}: {r.text[:200]}")
    except Exception as e:
        print(f"Endpoint {ep} error: {e}")

if not applied:
    # Try using postgresql via psycopg2 if available
    try:
        import psycopg2
        # Supabase connection string format: postgres://postgres.[project_ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
        print("HTTP endpoints failed (requires Supabase Dashboard SQL Editor).")
    except ImportError:
        pass

print("\n--- SQL TO RUN IN SUPABASE DASHBOARD ---")
print(f"If the policy could not be set automatically via API, open:")
print(f"https://supabase.com/dashboard/project/{project_ref}/sql/new")
print("And run this SQL statement:\n")
print(sql)
