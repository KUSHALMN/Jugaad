import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

client = create_client(url, key)

print("Querying worker_profiles view definition from pg_views...")
try:
    # PostgREST allows querying views if they are exposed in the schema
    # We can execute a custom query by requesting the definition from pg_views if allowed,
    # or by checking table/view structure via RPC if available.
    # Let's try selecting from information_schema.views or pg_views
    res = client.table("worker_profiles").select("*").limit(1).execute()
    print("Direct select query on worker_profiles succeeded.")
except Exception as e:
    print("Direct select query on worker_profiles failed:", e)

try:
    # Let's check which columns are in the view schema using a select query on information_schema.columns
    # We can try to RPC or fetch it.
    import httpx
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}"
    }
    resp = httpx.get(f"{url}/rest/v1/", headers=headers, timeout=10.0)
    if resp.status_code == 200:
        definitions = resp.json().get("definitions", {})
        wp_def = definitions.get("worker_profiles", {})
        properties = wp_def.get("properties", {})
        print("\nColumns in worker_profiles view according to schema spec:")
        for col_name in sorted(properties.keys()):
            print(f"  - {col_name}")
    else:
        print("Failed to fetch schema spec:", resp.status_code)
except Exception as e:
    print("Failed to inspect schema spec:", e)
