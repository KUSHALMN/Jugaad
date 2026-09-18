import os
import sys
from dotenv import load_dotenv

# Load backend environment from current or parent directory
load_dotenv(".env.local")
load_dotenv(".env")

if not os.environ.get("SUPABASE_SERVICE_KEY"):
    os.environ["SUPABASE_SERVICE_KEY"] = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

# Ensure backend root is in sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from fastapi.testclient import TestClient
from main import app
from routers.workers import resolve_search_category

def test_category_resolution():
    print("\n--- Testing Category Resolution ---")
    generic_cases = ["Service", "service", "services", "Service Specialist", "All", "pro", "helper"]
    for gc in generic_cases:
        cat, is_all = resolve_search_category(gc)
        assert is_all is True, f"Expected {gc} to resolve to is_all=True, got {is_all} (cat={cat})"
        print(f"  [OK] '{gc}' correctly resolved to all categories (is_all={is_all})")

    specific_cases = ["Electrician", "plumber", "ac_repair", "water purifier"]
    for sc in specific_cases:
        cat, is_all = resolve_search_category(sc)
        assert is_all is False, f"Expected {sc} to resolve to is_all=False, got {is_all}"
        print(f"  [OK] '{sc}' correctly resolved to canonical category '{cat}'")

def test_backend_search_highest_rated():
    print("\n--- Testing Backend /api/v1/workers/search for Highest-Rated Workers ---")
    client = TestClient(app)

    # 1. Search with category=Service (the exact scenario from the user screenshot)
    resp = client.get("/api/v1/workers/search?category=Service&lat=12.3051&lng=76.6551")
    assert resp.status_code == 200, f"Status code was {resp.status_code}: {resp.text}"
    data = resp.json()
    workers = data.get("workers", [])
    print(f"  Found {len(workers)} workers for category='Service' (mode={data.get('mode')})")
    assert len(workers) > 0, "Expected workers to be returned for category='Service', but got none!"
    print(f"  Top worker: {workers[0].get('name')} with rating {workers[0].get('rating')} stars, distance {workers[0].get('distance_m')}m")
    print("  [OK] Successfully retrieved available verified specialists for category='Service'!")

    # 2. Test citywide fallback mode (rating DESC sorting)
    resp_fallback = client.get("/api/v1/workers/search?category=Service&lat=12.9352&lng=77.6245")
    assert resp_fallback.status_code == 200
    data_fb = resp_fallback.json()
    fb_workers = data_fb.get("workers", [])
    assert len(fb_workers) > 0, "Expected fallback workers"
    ratings = [w.get("rating") for w in fb_workers if w.get("rating") is not None]
    for i in range(len(ratings) - 1):
        assert ratings[i] >= ratings[i+1], f"Fallback ratings not sorted DESC: {ratings[i]} < {ratings[i+1]}"
    print(f"  [OK] Fallback mode verified: sorted by Highest Rated DESC: {ratings[:5]}")

    # 3. Search specific category
    resp_elec = client.get("/api/v1/workers/search?category=electrician&lat=12.3051&lng=76.6551")
    assert resp_elec.status_code == 200
    data_elec = resp_elec.json()
    workers_elec = data_elec.get("workers", [])
    assert len(workers_elec) > 0, "Expected electrician workers to be returned"
    print(f"  [OK] Electrician search returned {len(workers_elec)} workers (top: {workers_elec[0].get('name')}, {workers_elec[0].get('rating')} stars)")

if __name__ == "__main__":
    test_category_resolution()
    test_backend_search_highest_rated()
    print("\n[ALL PASSED] All End-to-End Highest Rated Worker Search Tests PASSED successfully!")
