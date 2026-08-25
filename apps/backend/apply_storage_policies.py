import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv(".env.local")
load_dotenv(".env")

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

client = create_client(url, key)

print("Checking worker storage buckets accessibility...")
for bucket_id in ['worker-documents', 'worker-photos', 'worker-verification']:
    try:
        bucket = client.storage.get_bucket(bucket_id)
        print(f"✓ Bucket '{bucket_id}' exists and is public: {bucket.public}")
    except Exception as e:
        print(f"✗ Bucket '{bucket_id}' error: {e}")

print("Done checking buckets.")
