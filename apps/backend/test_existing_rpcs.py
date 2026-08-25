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

print("Testing find_nearby_workers RPC...")
try:
    res1 = client.rpc("find_nearby_workers", {
        "lat": 12.2958,
        "lng": 76.6394,
        "skill": "plumber",
        "radius_meters": 3000
    }).execute()
    print("find_nearby_workers result:", res1.data)
except Exception as e:
    print("find_nearby_workers error:", e)

print("\nTesting get_nearby_workers RPC...")
try:
    res2 = client.rpc("get_nearby_workers", {
        "user_lat": 12.2958,
        "user_lng": 76.6394,
        "service_type": "plumber",
        "radius_meters": 3000.0
    }).execute()
    print("get_nearby_workers result:", res2.data)
except Exception as e:
    print("get_nearby_workers error:", e)
