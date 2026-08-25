"""Quick Supabase connection test."""
import os
from dotenv import load_dotenv

load_dotenv()

from supabase import create_client

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

print(f"SUPABASE_URL: {url}")
print(f"SERVICE_KEY:  {'set (' + key[:20] + '...)' if key else 'NOT SET'}")

try:
    client = create_client(url, key)
    result = client.table("users").select("id").limit(1).execute()
    print(f"\n[OK] DATABASE CONNECTED SUCCESSFULLY!")
    print(f"     Users table query returned {len(result.data)} rows")
except Exception as e:
    print(f"\n[FAIL] CONNECTION FAILED: {e}")
