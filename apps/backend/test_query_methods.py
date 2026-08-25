import os
import math
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

def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000  # meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

# Test querying RPC search_workers_nearby or table select
category = "plumber"
user_lat = 12.2958
user_lng = 76.6394

print("1. Testing RPC search_workers_nearby...")
try:
    res = client.rpc("search_workers_nearby", {
        "p_category": category,
        "p_lat": user_lat,
        "p_lng": user_lng,
        "p_radius_m": 7000.0
    }).execute()
    print("RPC search_workers_nearby result:", res.data)
except Exception as e:
    print("RPC search_workers_nearby error:", e)

print("\n2. Testing direct table select with python haversine fallback...")
res_all = client.table("workers").select("*").execute()
workers = res_all.data or []
print("Total workers in table:", len(workers))
for w in workers:
    print("Worker:", w.get("name"), "| area:", w.get("area"), "| skills:", w.get("skills"))
