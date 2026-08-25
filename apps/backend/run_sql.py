import os
import sys
import httpx
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env.local")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    load_dotenv(dotenv_path=".env")
    SUPABASE_URL = os.getenv("SUPABASE_URL")
    SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    print("ERROR: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")
    sys.exit(1)

headers = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

def execute_sql(sql):
    print(f"Executing SQL:\n{sql}\n")
    
    endpoints_to_try = [
        (f"{SUPABASE_URL}/rest/v1/rpc/exec_sql", {"sql": sql}),
        (f"{SUPABASE_URL}/pg/query", {"query": sql}),
        (f"{SUPABASE_URL}/sql", {"query": sql}),
    ]
    
    for url, payload in endpoints_to_try:
        try:
            response = httpx.post(url, headers=headers, json=payload, timeout=30.0)
            if response.status_code in (200, 201):
                print(f"SUCCESS via endpoint: {url}")
                print(response.text)
                return True, response.json()
            else:
                print(f"Failed via {url}: {response.status_code} - {response.text[:300]}")
        except Exception as e:
            print(f"Error via {url}: {e}")
            
    # Try supabase rpc if endpoints fail
    try:
        from supabase import create_client
        sb = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        result = sb.rpc("exec_sql", {"sql": sql}).execute()
        print("SUCCESS via supabase-py RPC")
        print(result.data)
        return True, result.data
    except Exception as e:
        print(f"Failed via supabase-py RPC: {e}")
        
    return False, None

if __name__ == "__main__":
    # If a query is provided as argument, execute it; otherwise run a default check on users policies
    sql_to_run = sys.argv[1] if len(sys.argv) > 1 else """
    SELECT 
        schemaname,
        tablename,
        policyname,
        permissive,
        roles,
        cmd,
        qual,
        with_check
    FROM pg_policies
    WHERE tablename = 'users';
    """
    execute_sql(sql_to_run)
