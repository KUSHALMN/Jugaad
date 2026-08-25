import os
from dotenv import load_dotenv
from supabase import create_client

# Load environment variables
load_dotenv(dotenv_path=".env.local")

url = os.getenv("SUPABASE_URL")
service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

client = create_client(url, service_key)

tables = ["users", "workers", "jobs"]

print("Testing count with SERVICE ROLE key (bypassing RLS):")
for table in tables:
    try:
        res = client.table(table).select("*", count="exact").execute()
        print(f"Table '{table}': {len(res.data)} rows in database.")
    except Exception as e:
        print(f"Table '{table}': FAILED! Error: {e}")
