"""
Debug script: Check/Create test worker in Supabase (replaces Firestore version).
Usage: python check_worker.py
"""
import os
from dotenv import load_dotenv

load_dotenv()

from shared.database import get_supabase

supabase = get_supabase()

WORKER_ID = "test-worker-001"

# Check if test worker exists
result = supabase.table("workers").select("*").eq("id", WORKER_ID).execute()

if result.data:
    print(f"Worker {WORKER_ID} exists:", result.data[0])
else:
    print(f"Worker {WORKER_ID} NOT found. Creating...")

    # Ensure user record exists first (FK constraint)
    supabase.table("users").upsert({
        "id": WORKER_ID,
        "firebase_uid": WORKER_ID,
        "name": "Kushal the Plumber",
        "phone": "+919999900001",
        "role": "worker",
    }).execute()

    # Create worker record
    supabase.table("workers").upsert({
        "id": WORKER_ID,
        "worker_id": WORKER_ID,
        "name": "Kushal the Plumber",
        "phone": "+919999900001",
        "skills": ["plumber"],
        "approval_status": "pending",
        "is_available": True,
        "location": "POINT(76.6552 12.3052)",  # Mysuru center (lng lat)
        "rating": 4.9,
        "rate_per_hour": 200,
    }).execute()

    print(f"Worker {WORKER_ID} created successfully in Supabase.")
