import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

print("SUPABASE_URL:", url)
client = create_client(url, key)

try:
    print("\n--- Trying to fetch workers limit 1 ---")
    res = client.table("workers").select("id").limit(1).execute()
    print("Success:", res.data)
except Exception as e:
    print("Error:", e)

try:
    print("\n--- Trying to fetch worker_profiles limit 1 ---")
    res = client.table("worker_profiles").select("*").limit(1).execute()
    print("Success:", res.data)
except Exception as e:
    print("Error:", e)
