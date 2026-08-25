import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

client = create_client(url, key)

print("Checking jobs table for emergency columns...")
try:
    res = client.table("jobs").select("job_type").limit(1).execute()
    print("Jobs job_type exists! Data:", res.data)
except Exception as e:
    print("Jobs job_type query failed:", e)

print("\nChecking workers table for emergency_available...")
try:
    res = client.table("workers").select("emergency_available").limit(1).execute()
    print("Workers emergency_available exists! Data:", res.data)
except Exception as e:
    print("Workers emergency_available query failed:", e)
