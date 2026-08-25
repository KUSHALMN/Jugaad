"""
Apply the worker_approval_columns_fix migration to Supabase.
Adds missing columns: is_active, approved_at, approved_by, rejection_reason,
work_category, city, total_completed_jobs, approval_status_updated_at.
"""
import os
from dotenv import load_dotenv
load_dotenv(".env.local")

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not url or not key:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set")
    exit(1)

sql_path = os.path.join(os.path.dirname(__file__), "supabase", "worker_approval_columns_fix.sql")
with open(sql_path, "r") as f:
    sql = f.read()

# Split into individual statements and execute each
import httpx

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# Use Supabase SQL endpoint (postgrest doesn't support DDL, but we can use the RPC endpoint)
# For DDL, we need to use the pg_net or direct SQL approach
from supabase import create_client
db = create_client(url, key)

# Split SQL into statements (naive split on semicolons outside comments)
statements = []
current = []
for line in sql.split('\n'):
    stripped = line.strip()
    if stripped.startswith('--') or not stripped:
        continue
    current.append(line)
    if stripped.endswith(';'):
        stmt = '\n'.join(current).strip()
        if stmt and stmt != ';':
            statements.append(stmt)
        current = []

# For compound statements (CREATE OR REPLACE FUNCTION), rejoin $$ blocks
merged = []
i = 0
while i < len(statements):
    stmt = statements[i]
    # Check if this starts a $$ block that hasn't been closed
    dollar_count = stmt.count('$$')
    while dollar_count % 2 != 0 and i + 1 < len(statements):
        i += 1
        stmt = stmt + '\n' + statements[i]
        dollar_count = stmt.count('$$')
    merged.append(stmt)
    i += 1

print(f"Found {len(merged)} SQL statements to execute.\n")

success = 0
failed = 0
for idx, stmt in enumerate(merged):
    short = stmt[:100].replace('\n', ' ')
    print(f"[{idx+1}/{len(merged)}] {short}...")
    try:
        # Use raw SQL via RPC
        result = db.rpc("exec_sql", {"query": stmt}).execute()
        print(f"  OK (via RPC)")
        success += 1
    except Exception as e:
        # RPC may not exist — try alternative approach via PostgREST
        err_msg = str(e)
        if "exec_sql" in err_msg or "does not exist" in err_msg:
            # Use httpx to call the pg endpoint directly
            try:
                resp = httpx.post(
                    f"{url}/rest/v1/rpc/exec_sql",
                    headers=headers,
                    json={"query": stmt},
                    timeout=30.0,
                )
                if resp.status_code < 300:
                    print(f"  OK (via HTTP RPC)")
                    success += 1
                else:
                    print(f"  WARN: HTTP {resp.status_code} - {resp.text[:200]}")
                    failed += 1
            except Exception as http_err:
                print(f"  FAILED: {http_err}")
                failed += 1
        else:
            # Check for "already exists" type errors which are OK
            if "already exists" in err_msg or "duplicate" in err_msg.lower():
                print(f"  OK (already exists)")
                success += 1
            else:
                print(f"  FAILED: {err_msg[:200]}")
                failed += 1

print(f"\nDone: {success} succeeded, {failed} failed.")
if failed > 0:
    print("\nNOTE: If DDL statements failed, you may need to run the SQL manually")
    print(f"in the Supabase SQL Editor: {url.replace('.supabase.co', '.supabase.co')}")
    print(f"File: supabase/worker_approval_columns_fix.sql")
