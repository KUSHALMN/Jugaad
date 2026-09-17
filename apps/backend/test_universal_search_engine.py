"""
Automated Test Suite for Universal Worker Search Engine & Animations
=====================================================================
Validates:
1. Category alias & natural language resolution.
2. Coordinate fault-tolerance: null, 0.0, string, out-of-bound coords never crash.
3. Multi-location queries across active cities & regions.
4. Response contract integrity & worker schema verification.
5. Geospatial division & multi-city resolution (Mysuru, Bengaluru, Mandya, etc.).
6. Citywide high-rated worker fallback & customer busy advisory generation.
7. Upcoming city expansion detection & onboarding advisory.
"""

import sys
import os

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(__file__))

from routers.workers import (
    search_workers,
    resolve_search_category,
    resolve_city_and_division,
    CITY_DIVISIONS_REGISTRY,
    SERVICE_KEYWORD_MAP,
)


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


def test_division_resolution():
    print("\n--- Test 5: Geospatial Division & Multi-City Resolution ---")
    test_coords = [
        (12.3308, 76.6267, "Mysuru", "Gokulam"),
        (12.2905, 76.6277, "Mysuru", "Kuvempunagar"),
        (12.9352, 77.6245, "Bengaluru", "Koramangala"),
        (12.9784, 77.6408, "Bengaluru", "Indiranagar"),
        (12.5226, 76.8974, "Mandya", "Mandya City Center"),
        (13.0072, 76.1029, "Hassan", "Hassan City Center"),
        (15.3647, 75.1240, "Hubli", "Hubli City Center"),
        (12.9141, 74.8560, "Mangaluru", "Mangaluru Central"),
    ]
    for lat, lng, exp_city, exp_div in test_coords:
        city, div, is_up = resolve_city_and_division(lat, lng)
        assert city == exp_city, f"Expected city {exp_city}, got {city}"
        assert div == exp_div, f"Expected division {exp_div}, got {div}"
        assert not is_up, f"Expected is_upcoming=False for registered city {city}"
        print(f"  [OK] Coords ({lat}, {lng}) -> City: {city}, Division: {div}")
    print("All division and multi-city resolution tests passed!")


def test_citywide_high_rated_fallback_advisory():
    print("\n--- Test 6: Citywide High-Rated Fallback & Customer Busy Advisory ---")
    # Query Koramangala, Bengaluru where local workers might not be registered:
    res = search_workers(lat=12.9352, lng=77.6245, category="plumber")
    assert res is not None
    assert "advisory_message" in res
    assert "user_city" in res
    assert "user_division" in res
    assert "is_fallback" in res

    advisory = res["advisory_message"]
    print(f"  [Advisory Generated] {advisory}")
    assert "Workers in your region (Koramangala) are currently busy" in advisory
    assert "high-rated Plumber" in advisory or "Plumber" in advisory
    assert "Bengaluru" in advisory

    workers = res.get("workers", [])
    if len(workers) >= 2:
        # Check that workers are sorted by rating DESC (highest rated first)
        ratings = [w.get("rating") for w in workers if w.get("rating") is not None]
        for i in range(len(ratings) - 1):
            assert ratings[i] >= ratings[i + 1], f"Workers must be sorted rating DESC: {ratings}"
        print(f"  [OK] Workers properly ranked by rating DESC: {ratings[:5]}")
    print("Citywide high-rated fallback and customer busy advisory tests passed!")


def test_upcoming_city_expansion_advisory():
    print("\n--- Test 7: Upcoming City & Regional Hub Expansion Advisory ---")
    # Query an upcoming location (e.g. 14.5, 75.8)
    res = search_workers(lat=14.5, lng=75.8, category="electrician")
    assert res is not None
    assert res.get("is_upcoming_city") is True or "Upcoming City" in res.get("user_city", "")
    advisory = res.get("advisory_message", "")
    print(f"  [Upcoming Advisory] {advisory}")
    assert "Workers in your region" in advisory
    assert "Electrician" in advisory
    print("Upcoming city expansion advisory tests passed!")


if __name__ == "__main__":
    test_category_alias_resolution()
    test_coordinate_fault_tolerance()
    test_multi_location_searches()
    test_response_contract_fields()
    test_division_resolution()
    test_citywide_high_rated_fallback_advisory()
    test_upcoming_city_expansion_advisory()
    print("\n==================================================")
    print(">>> ALL 7 TEST SUITES COMPLETED WITH 100% SUCCESS!")
    print("==================================================")

