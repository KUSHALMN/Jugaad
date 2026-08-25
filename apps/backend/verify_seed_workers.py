"""
VERIFICATION SCRIPT FOR SEEDED WORKERS
Queries Supabase 'workers' table and outputs verification of all 13 seed workers.
"""
import os
from shared.database import supabase

def main():
    res = supabase.table("workers").select("id, name, phone, area, skills, rating, total_jobs, is_available, status").execute()
    workers = res.data or []
    
    print("==================================================")
    print(f"VERIFICATION: Found {len(workers)} workers in Supabase DB")
    print("==================================================")
    
    for idx, w in enumerate(workers, 1):
        name = w.get("name")
        phone = w.get("phone")
        area = w.get("area")
        skills = w.get("skills", [])
        rating = w.get("rating")
        total_jobs = w.get("total_jobs")
        status = w.get("status")
        available = w.get("is_available")
        
        print(f"{idx:2d}. {name:<42} | Rating: {rating} ({total_jobs} reviews) | Phone: {phone} | Skills: {skills} | Status: {status} (Avail: {available})")
        print(f"    Address: {area}\n")

if __name__ == "__main__":
    main()
