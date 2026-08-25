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

print("Checking job_requests table...")
try:
    res = client.table("job_requests").select("*").limit(1).execute()
    print("job_requests table exists. Sample:", res.data)
except Exception as e:
    print("job_requests query error:", e)

print("Checking job_notification_attempts table...")
try:
    res = client.table("job_notification_attempts").select("*").limit(1).execute()
    print("job_notification_attempts table exists. Sample:", res.data)
except Exception as e:
    print("job_notification_attempts query error:", e)
