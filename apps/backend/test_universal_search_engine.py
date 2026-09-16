"""
Automated Test Suite for Universal Worker Search Engine & Animations
=====================================================================
Validates:
1. Coordinate fault-tolerance: null, 0.0, string, out-of-bound coords never crash.
2. Multi-location queries: Mysuru, Bengaluru, Mandya, Delhi, global test points.
3. Natural language category aliases: "pipe leak", "short circuit", "ac gas", "purifier".
4. Contract integrity: returns valid JSON with count, mode, and worker fields.
"""

import sys
import os

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(__file__))

from routers.workers import search_workers, resolve_search_category, SERVICE_KEYWORD_MAP

def test_category_alias_resolution():
    print("\n--- Test 1: Category Alias & Natural Language Resolution ---")
    test_cases = [
        ("pipe leak", "plumber"),
        ("water tap", "plumber"),
        ("short circuit", "electrician"),
        ("inverter repair", "electrician"),
        ("ac gas refill", "ac_service"),
        ("laptop display", "laptop_repair"),
        ("phone screen", "phone_repair"),
        ("water purifier", "ro_service"),
        ("deep house clean", "cleaning"),
        ("sofa wood", "carpenter"),
        ("all", ""),
        ("*", ""),
    ]
    for query, expected in test_cases:
        cat, is_all = resolve_search_category(query)
        assert cat == expected, f"Failed for query '{query}': expected '{expected}', got '{cat}'"
        print(f"  [OK] Query '{query}' resolved to '{cat}' (is_all: {is_all})")
    print("All category alias resolution tests passed!")


def test_coordinate_fault_tolerance():
    print("\n--- Test 2: Coordinate Fault-Tolerance (Zero 400/500 Errors) ---")
    faulty_coords = [
        (None, None),
        (0.0, 0.0),
        ("0.0", "0.0"),
        (999.0, 999.0),   # out of range
        (-999.0, -999.0), # out of range
        ("invalid", "invalid"),
        (None, 76.6551),
        (12.3051, None),
    ]
    for lat, lng in faulty_coords:
        try:
            res = search_workers(lat=lat, lng=lng, category="plumber")
            assert isinstance(res, dict), "Result must be a dictionary"
            assert "workers" in res, "Result must contain workers key"
            assert "mode" in res, "Result must contain mode key"
            print(f"  [OK] Passed for lat={lat}, lng={lng} -> mode={res['mode']}, count={res['count']}")
        except Exception as e:
            raise AssertionError(f"search_workers crashed on lat={lat}, lng={lng}: {e}")
    print("All coordinate fault-tolerance tests passed!")


def test_multi_location_searches():
    print("\n--- Test 3: Multi-Location Regional Searches ---")
    locations = [
        ("Mysuru Palace Center", 12.3051, 76.6551),
        ("Gokulam Mysuru", 12.3308, 76.6267),
        ("Bengaluru Koramangala", 12.9352, 77.6245),
        ("Bengaluru Indiranagar", 12.9784, 77.6408),
        ("Mandya Center", 12.5226, 76.8974),
        ("New Delhi Center", 28.6139, 77.2090),
        ("Mumbai BKC", 19.0607, 72.8687),
    ]
    for loc_name, lat, lng in locations:
        res = search_workers(lat=lat, lng=lng, category="electrician")
        assert res is not None and "workers" in res
        mode = res.get("mode")
        count = res.get("count", 0)
        assert mode in ["nearest", "citywide_rating_fallback", "no_workers_found"]
        print(f"  [OK] {loc_name} ({lat}, {lng}): mode={mode}, count={count}")
    print("All multi-location regional search tests passed!")


def test_response_contract_fields():
    print("\n--- Test 4: Response Contract & Worker Object Schema ---")
    res = search_workers(lat=12.3051, lng=76.6551, category="all")
    workers = res.get("workers", [])
    assert len(workers) > 0, "Expected at least 1 worker for 'all'"
    w = workers[0]
    required_keys = ["id", "name", "category", "rating", "is_verified", "is_available"]
    for key in required_keys:
        assert key in w, f"Missing required worker field: {key}"
    print(f"  [OK] Sample worker: {w['name']} ({w['category']}), rating={w['rating']}, dist={w.get('distance_m')}m")
    print("Response contract test passed!")


if __name__ == "__main__":
    test_category_alias_resolution()
    test_coordinate_fault_tolerance()
    test_multi_location_searches()
    test_response_contract_fields()
    print("\n==================================================")
    print(">>> ALL 4 TEST SUITES COMPLETED WITH 100% SUCCESS!")
    print("==================================================")
