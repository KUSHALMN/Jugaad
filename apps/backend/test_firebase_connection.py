"""Quick Firebase connection test."""
from dotenv import load_dotenv
load_dotenv()

print("--- Testing Firebase Admin SDK ---")
try:
    import shared.firebase_init
    import firebase_admin
    from firebase_admin import auth
    
    app = firebase_admin.get_app()
    print(f"[OK] Firebase App initialized successfully! Project: {app.project_id}")
    
    # Try fetching users (requires valid auth)
    # Just fetching a page of users to confirm the network/credentials work
    try:
        page = auth.list_users(max_results=1)
        print(f"[OK] Successfully queried Firebase Auth!")
    except Exception as fetch_err:
        print(f"[WARNING] Firebase app initialized, but querying Auth failed (maybe permission error or empty?): {fetch_err}")

except ImportError as e:
    print(f"[SKIP] Firebase packages/modules missing: {e}")
except Exception as e:
    print(f"[FAIL] Firebase Initialization Failed: {e}")
