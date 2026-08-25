import httpx
from .logging import log
from .database import supabase
from datetime import datetime, timezone


async def reverse_geocode(lat: float, lng: float) -> str:
    """
    Nominatim reverse geocoding with Supabase Caching.
    Uses truncated lat/lng as cache key (~100m resolution) instead of geohash.
    """
    # Truncate to 3 decimal places ≈ 111m resolution — good enough for caching
    g_hash = f"{lat:.3f},{lng:.3f}"
    
    # 1. Check Supabase cache first
    try:
        result = supabase.table("geocache").select("address").eq("geohash", g_hash).execute()
        if result.data and len(result.data) > 0:
            address = result.data[0].get("address")
            log("shared", "geocoding", "cache_hit", lat=lat, lng=lng, geohash=g_hash, address=address)
            return address
    except Exception as e:
        log("shared", "geocoding", "cache_check_failed", severity="WARNING", error=str(e))

    # 2. Call Nominatim if not cached
    url = "https://nominatim.openstreetmap.org/reverse"
    params = {
        "lat": lat,
        "lon": lng,
        "format": "json"
    }
    headers = {
        "User-Agent": "Jugaad/1.0 (jugaad@mysuru.in)"
    }
    
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url, params=params, headers=headers)
            if response.status_code == 200:
                data = response.json()
                address = data.get("display_name", f"{lat},{lng}")
                
                # 3. Store result in cache
                try:
                    supabase.table("geocache").upsert({
                        "geohash": g_hash,
                        "address": address,
                        "updated_at": datetime.now(timezone.utc).isoformat()
                    }).execute()
                except Exception as cache_err:
                    log("shared", "geocoding", "cache_store_failed", severity="WARNING", error=str(cache_err))
                
                log("shared", "geocoding", "reverse_geocode_success", lat=lat, lng=lng, address=address)
                return address
            else:
                log("shared", "geocoding", "nominatim_api_error", severity="WARNING", status=response.status_code)
    except Exception as e:
        log("shared", "geocoding", "reverse_geocode_timeout_or_error", severity="WARNING", error=str(e))
    
    # 4. Fallback: Never fail enrollment
    return f"{lat},{lng}"
