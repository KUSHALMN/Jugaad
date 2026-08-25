import os
import httpx
from dotenv import load_dotenv

load_dotenv()

sb_url = os.getenv("SUPABASE_URL")
sb_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

headers = {
    "apikey": sb_key,
    "Authorization": f"Bearer {sb_key}"
}

print("Fetching columns from PostgREST OpenAPI spec...")
resp = httpx.get(f"{sb_url}/rest/v1/", headers=headers, timeout=10.0)
if resp.status_code == 200:
    data = resp.json()
    definitions = data.get("definitions", {})
    
    for table_name in ["workers", "users", "jobs"]:
        table_def = definitions.get(table_name, {})
        properties = table_def.get("properties", {})
        print(f"\nColumns for '{table_name}':")
        for col_name, col_info in sorted(properties.items()):
            print(f"  - {col_name}: {col_info.get('type')} ({col_info.get('format', 'no format')})")
else:
    print("Failed to fetch schema. Status:", resp.status_code)
