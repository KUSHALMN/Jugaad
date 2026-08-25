import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

sb_url = os.getenv("SUPABASE_URL")
sb_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

client = create_client(sb_url, sb_key)

# 1. Create a dummy user
dummy_id = "test-worker-id-123"
try:
    print("Creating dummy user...")
    client.table("users").upsert({
        "id": dummy_id,
        "name": "Test Worker",
        "role": "worker",
        "email": "testworker@example.com",
        "phone": "+911234567890"
    }).execute()
    
    # 2. Create a dummy worker
    print("Creating dummy worker...")
    client.table("workers").upsert({
        "id": dummy_id,
        "name": "Test Worker",
        "is_available": True,
        "is_online": True
    }).execute()

    # 3. Try to update worker_profiles view
    print("Trying to update worker_profiles view...")
    res = client.table("worker_profiles").update({
        "current_location": "POINT(76.6552 12.3052)",
        "is_available": False
    }).eq("id", dummy_id).execute()
    print("Successfully updated worker_profiles view:", res.data)

except Exception as e:
    print("Failed to update view directly:", e)

finally:
    # Cleanup
    print("Cleaning up test worker and user...")
    try:
        client.table("workers").delete().eq("id", dummy_id).execute()
        client.table("users").delete().eq("id", dummy_id).execute()
    except Exception as cleanup_err:
         print("Cleanup failed:", cleanup_err)
