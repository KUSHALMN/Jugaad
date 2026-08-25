import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv(".env.local")
url = os.getenv("SUPABASE_URL")
service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not url or not service_key:
    load_dotenv(".env")
    url = os.getenv("SUPABASE_URL")
    service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

client = create_client(url, service_key)

print("Verifying workers table columns...")
res = client.table("workers").select("*").limit(1).execute()
print("Sample worker row keys:", list(res.data[0].keys()) if res.data else "No rows")
