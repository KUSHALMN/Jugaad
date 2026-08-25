import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

client = create_client(url, key)

try:
    print("Calling postgis_full_version RPC...")
    res = client.rpc("postgis_full_version", {}).execute()
    print("Success! Version details:")
    print(res.data)
except Exception as e:
    print("Error calling RPC:", e)
