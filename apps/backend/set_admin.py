import firebase_admin
from firebase_admin import auth, credentials

# Use service account key
cred = credentials.Certificate('sa-key.json')
firebase_admin.initialize_app(cred, {"projectId": "jugaad-prod-app-2026"})

def set_admin_claim(identifier, is_email=True):
    try:
        if is_email:
            user = auth.get_user_by_email(identifier)
        else:
            user = auth.get_user_by_phone_number(identifier)
        
        auth.set_custom_user_claims(user.uid, {'admin': True})
        print(f"SUCCESS: Admin claim successfully set for {identifier} (UID: {user.uid})")
    except Exception as e:
        print(f"FAILED: Failed to set admin claim for {identifier}: {e}")

if __name__ == "__main__":
    # The user email
    set_admin_claim("kushikushal416@gmail.com", is_email=True)
    # The test phone number
    set_admin_claim("+919876543210", is_email=False)
