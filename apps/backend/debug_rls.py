import os
from dotenv import load_dotenv
from supabase import create_client

# Load environment variables
load_dotenv(dotenv_path=".env.local")

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

client = create_client(url, key)

try:
    print("Checking RLS policies for table 'users'...")
    # We can run an RPC or raw SQL query if we have postgres, or we can check the table definition.
    # Since we can't run arbitrary SQL via the standard SDK directly without a function,
    # let's see if we can query pg_policies using an RPC, or check if we can execute a query.
    # Wait, does the supabase python client support raw SQL? No, only RPC or standard tables.
    # But we can query the pg_policies view using standard supabase table read if it's exposed,
    # or we can test querying the users table as an anon user vs authenticated user!
    
    # Let's test reading public.users using the ANON key (to see what is visible without auth)
    anon_key = os.getenv("SUPABASE_ANON_KEY")
    if not anon_key:
        load_dotenv(dotenv_path=".env")
        anon_key = os.getenv("SUPABASE_ANON_KEY")
        
    anon_client = create_client(url, anon_key)
    
    # Test reading as anon
    print("Testing read as anon...")
    try:
        res = anon_client.table("users").select("role").eq("id", "c3b5bb62-8d1f-4a10-a071-9bf818cf66dc").execute()
        print("Anon read result:", res.data)
    except Exception as e:
        print("Anon read failed:", e)

    # Test reading as the specific authenticated user!
    print("\nTesting read as authenticated user (kushikushal416@gmail.com)...")
    try:
        user_client = create_client(url, anon_key)
        session = user_client.auth.sign_in_with_password({"email": "kushikushal416@gmail.com", "password": "admin12345"})
        print("Sign in success, checking role query...")
        res = user_client.table("users").select("role").eq("id", session.user.id).execute()
        print("Authenticated user read result:", res.data)
    except Exception as e:
        print("Authenticated user read failed:", e)

except Exception as e:
    print(f"Error: {e}")
