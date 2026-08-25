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

# Test the query that jobs_screen.dart executes:
# select=*,worker:users!jobs_worker_id_fkey(name,phone)
print("Testing select query with jobs_worker_id_fkey...")
url = f"{sb_url}/rest/v1/jobs?select=*,worker:users!jobs_worker_id_fkey(name,phone)&limit=1"
resp = httpx.get(url, headers=headers)
print("Response code:", resp.status_code)
print("Response text:", resp.text)

# Let's also test querying the schema info / relationships for jobs table:
print("\nTesting simple query to see user relationships for jobs...")
url_simple = f"{sb_url}/rest/v1/jobs?select=*,users(name)&limit=1"
resp_simple = httpx.get(url_simple, headers=headers)
print("Simple response code:", resp_simple.status_code)
print("Simple response text:", resp_simple.text)
