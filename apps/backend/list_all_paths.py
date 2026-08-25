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

print("Fetching PostgREST schema for:", sb_url)
resp = httpx.get(f"{sb_url}/rest/v1/", headers=headers, timeout=10.0)
if resp.status_code == 200:
    data = resp.json()
    paths = list(data.get("paths", {}).keys())
    print("\n--- Registered Paths/Tables/Views ---")
    for p in sorted(paths):
        print("  ", p)
else:
    print("Failed to fetch schema. Status:", resp.status_code)
    print("Response:", resp.text)
