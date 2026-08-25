# shared/geo.py
import os
from math import radians, sin, cos, sqrt, atan2

# Import canonical skills list from models — do NOT duplicate here
from shared.models import VALID_SKILLS  # noqa: F401
VALID_AREAS = [
    "vijayanagar_mysuru", "kuvempunagar_mysuru", "jayalakshmipuram_mysuru",
    "saraswathipuram_mysuru", "gokulam_mysuru", "hebbal_mysuru",
    "bannimantap_mysuru", "nazarbad_mysuru", "lakshmipuram_mysuru",
    "jayanagar_mysuru", "ramakrishnanagar_mysuru", "siddarthanagar_mysuru",
    "yadavagiri_mysuru", "hootagalli_mysuru", "bogadi_mysuru",
    "alanahalli_mysuru", "chamundi_hill_mysuru", "metagalli_mysuru",
    "kc_layout_mysuru", "udayagiri_mysuru", "srirampura_mysuru",
    "niveditha_nagar_mysuru", "dattagalli_mysuru", "jp_nagar_mysuru",
    "kesare_mysuru", "belavadi_mysuru", "other_mysuru"
]

# Pilot bounds — env-configurable, never hardcode coords in source
PILOT_CENTER_LAT = float(os.getenv("PILOT_LAT_CENTER", "12.3051"))
PILOT_CENTER_LNG = float(os.getenv("PILOT_LNG_CENTER", "76.6551"))
PILOT_RADIUS_KM = 10.0

PILOT_BOUNDS = {
    "PILOT_CENTER_LAT": PILOT_CENTER_LAT,
    "PILOT_CENTER_LNG": PILOT_CENTER_LNG,
    "PILOT_RADIUS_KM": PILOT_RADIUS_KM,
}


# ─── Geohash functions REMOVED ──────────────────────────────────
# encode, decode, neighbors_for_radius, geohash_neighbors, encode_geohash
# All replaced by PostGIS ST_DWithin via Supabase RPC (find_nearby_workers).
# pygeohash dependency removed from requirements.txt.


# ─── Haversine ───────────────────────────────────────────────────

def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Haversine formula — returns distance in km."""
    R = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))

