import os
from dotenv import load_dotenv
from supabase import create_client

# Load environment variables
load_dotenv(dotenv_path=".env.local")

url = os.getenv("SUPABASE_URL")
anon_key = os.getenv("SUPABASE_ANON_KEY")

if not anon_key:
    load_dotenv(dotenv_path=".env")
    anon_key = os.getenv("SUPABASE_ANON_KEY")

client = create_client(url, anon_key)

tables = ["users", "workers", "jobs", "services"]

print("Testing SELECT queries on tables using ANON key:")
for table in tables:
    try:
        res = client.table(table).select("*").limit(5).execute()
        print(f"Table '{table}': Success! Returned {len(res.data)} rows.")
        if len(res.data) > 0:
            print(f"  First row keys: {list(res.data[0].keys())}")
    except Exception as e:
        print(f"Table '{table}': FAILED! Error: {e}")
