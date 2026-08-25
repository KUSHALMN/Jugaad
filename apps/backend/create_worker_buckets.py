"""
Create Supabase Storage Buckets for Worker Photos and Aadhaar Documents.
Buckets created:
  - worker-documents (Aadhaar Card documents, ID proofs)
  - worker-photos (Worker profile photos & avatars)
  - worker-verification (Verification documents)
"""
import os
from dotenv import load_dotenv
from supabase import create_client

# Load environment variables
load_dotenv(".env.local")
load_dotenv(".env")

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY")

if not url or not key:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set")
    exit(1)

print(f"Connecting to Supabase at: {url}")
db = create_client(url, key)

buckets_to_create = [
    {
        "id": "worker-documents",
        "name": "worker-documents",
        "public": True,
        "file_size_limit": 10485760, # 10MB
        "allowed_mime_types": ["image/jpeg", "image/png", "image/webp", "application/pdf"],
    },
    {
        "id": "worker-photos",
        "name": "worker-photos",
        "public": True,
        "file_size_limit": 10485760, # 10MB
        "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"],
    },
    {
        "id": "worker-verification",
        "name": "worker-verification",
        "public": True,
        "file_size_limit": 10485760, # 10MB
        "allowed_mime_types": ["image/jpeg", "image/png", "image/webp", "application/pdf"],
    },
]

for b in buckets_to_create:
    try:
        res = db.storage.create_bucket(
            b["id"],
            options={
                "public": b["public"],
                "file_size_limit": b["file_size_limit"],
                "allowed_mime_types": b["allowed_mime_types"],
            }
        )
        print(f"SUCCESS: Created bucket '{b['id']}' -> {res}")
    except Exception as e:
        err_msg = str(e)
        if "already exists" in err_msg or "Duplicate" in err_msg or "409" in err_msg:
            print(f"INFO: Bucket '{b['id']}' already exists.")
        else:
            print(f"WARNING: Could not create bucket '{b['id']}': {err_msg}")

# Create SQL migration file as well for reference/reproducibility
sql_content = """-- Migration: Create Storage Buckets for Worker Photos and Aadhaar Card Documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('worker-documents', 'worker-documents', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('worker-photos', 'worker-photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('worker-verification', 'worker-verification', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Public Read worker buckets" ON storage.objects;
CREATE POLICY "Public Read worker buckets" ON storage.objects
  FOR SELECT TO public USING (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));

DROP POLICY IF EXISTS "Public Upload worker buckets" ON storage.objects;
CREATE POLICY "Public Upload worker buckets" ON storage.objects
  FOR INSERT TO public WITH CHECK (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));

DROP POLICY IF EXISTS "Public Update worker buckets" ON storage.objects;
CREATE POLICY "Public Update worker buckets" ON storage.objects
  FOR UPDATE TO public USING (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));
"""

sql_file_path = os.path.join(os.path.dirname(__file__), "supabase", "create_worker_storage_buckets.sql")
with open(sql_file_path, "w") as f:
    f.write(sql_content)

print(f"Saved SQL migration to: {sql_file_path}")
print("All worker storage buckets setup complete!")
