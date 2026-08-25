import os
import sys
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

sb_url = os.getenv("SUPABASE_URL")
sb_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

if not sb_url or not sb_key:
    print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in your .env / .env.local file.")
    sys.exit(1)

supabase: Client = create_client(sb_url, sb_key)

def create_admin(email, password, name, phone):
    print(f"Creating Auth user for {email}...")
    try:
        # Create user in Supabase Auth via Admin API (bypassing email verification confirmation)
        auth_response = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True
        })
        
        user_id = auth_response.user.id
        print(f"Auth user created successfully! UID: {user_id}")
        
        # Insert user profile into public.users table with role='admin'
        print("Inserting user profile into public.users table...")
        db_response = supabase.table("users").upsert({
            "id": user_id,
            "name": name,
            "email": email,
            "phone": phone,
            "role": "admin"
        }, on_conflict="id").execute()
        
        print("\n[SUCCESS] Admin account registered successfully.")
        print(f"Email: {email}")
        print(f"Password: {password}")
        print(f"Phone: {phone}")
        print(f"UID: {user_id}")
        
    except Exception as e:
        print(f"\n[FAILED] Error: {e}")

if __name__ == "__main__":
    email = input("Enter admin email (default: admin@jugaad.com): ").strip() or "admin@jugaad.com"
    password = input("Enter admin password (default: admin12345): ").strip() or "admin12345"
    name = input("Enter admin name (default: Admin): ").strip() or "Admin"
    phone = input("Enter admin phone (default: +919999999999): ").strip() or "+919999999999"
    
    create_admin(email, password, name, phone)
