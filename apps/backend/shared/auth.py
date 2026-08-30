# shared/auth.py
import os
import hmac
import hashlib
import base64
from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as fb_auth
from shared.logging import log

INTERNAL_SECRET = os.getenv("INTERNAL_SECRET")

# FastAPI security scheme — makes Swagger UI show the 🔒 Authorize button
_bearer_scheme = HTTPBearer(auto_error=False)

# Local dev bypass — when ENV=local, requests without a token use this UID
from core.config import settings
_DEV_UID = os.getenv("DEV_UID", "dev-test-user")
_IS_LOCAL = settings.ENV == "local"


# ─── 1. Public Firebase token (Flutter app users + workers) ──────

def verify_token(authorization_header: str) -> dict:
    """Verify Firebase Auth ID token from Authorization header value."""
    if not authorization_header.startswith("Bearer "):
        raise HTTPException(401, "Missing token")
    token = authorization_header.split(" ", 1)[1]
    try:
        decoded = fb_auth.verify_id_token(token)
        log("auth", "verify_token", "ok", uid=decoded["uid"])
        return decoded
    except Exception as e:
        log("auth", "verify_token", "fail", error=str(e), severity="WARNING")
        raise HTTPException(401, "Invalid token")


def ensure_db_user(uid: str, decoded_token: dict = None) -> dict:
    """
    Ensure a user record exists in the Supabase 'users' table.
    If it doesn't exist, auto-provisions it using metadata from the decoded Firebase ID token.
    """
    from shared.database import supabase
    try:
        # Query user safely checking if response is None
        res = supabase.table("users").select("*").eq("firebase_uid", uid).maybe_single().execute()
        if res and res.data:
            return res.data
        
        # Provision new user
        email = None
        name = "User"
        phone = None
        if decoded_token:
            email = decoded_token.get("email")
            name = decoded_token.get("name") or decoded_token.get("display_name") or "User"
            phone = decoded_token.get("phone_number")
            
        if not phone:
            import hashlib
            h = int(hashlib.md5(uid.encode()).hexdigest(), 16)
            dummy_num = str(h % 10000000000).zfill(10)
            phone = f"+91{dummy_num}"
            
        new_user = {
            "id": uid,
            "firebase_uid": uid,
            "email": email,
            "name": name,
            "phone": phone,
            "role": "employer",  # Default role is employer (customer)
        }
        insert_res = supabase.table("users").insert(new_user).execute()
        log("auth", "ensure_db_user", "auto_provision_success", uid=uid)
        
        if insert_res and insert_res.data:
            return insert_res.data[0]
        return new_user
        
    except Exception as e:
        log("auth", "ensure_db_user", "auto_provision_failed", uid=uid, error=str(e), severity="ERROR")
        # Fallback to query
        try:
            res = supabase.table("users").select("*").eq("firebase_uid", uid).maybe_single().execute()
            if res and res.data:
                return res.data
        except Exception:
            pass
        raise HTTPException(500, f"Database user synchronization failed: {str(e)}")


def get_current_user(request: Request) -> dict:
    """FastAPI dependency — extracts and verifies Firebase token. Returns full decoded dict."""
    auth_header = request.headers.get("X-Forwarded-Authorization")
    if not auth_header:
        auth_header = request.headers.get("Authorization", "")
    decoded = verify_token(auth_header)
    ensure_db_user(decoded["uid"], decoded)
    return decoded


def verify_firebase_token(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> str:
    """
    FastAPI dependency — extracts Firebase ID token, verifies it,
    and returns ONLY the uid string.
    Usage: uid: str = Depends(verify_firebase_token)

    In local dev mode (ENV=local), if no token is provided, returns DEV_UID
    so you can test endpoints from Swagger without a real Firebase token.
    """
    auth_header = request.headers.get("X-Forwarded-Authorization")
    if not auth_header:
        auth_header = request.headers.get("Authorization", "")

    if not auth_header:
        raise HTTPException(401, "Missing Authorization Bearer token")

    decoded = verify_token(auth_header)
    uid = decoded["uid"]
    ensure_db_user(uid, decoded)
    return uid


# ─── 2. Internal service-to-service auth (Render shared secret) ──
#     Replaces GCP OIDC (verify_pubsub_oidc + verify_oidc_token)

def verify_internal_secret(request: Request) -> None:
    """
    Replaces GCP OIDC for internal service-to-service auth on Render.
    Pass X-Internal-Secret header in all /internal/* calls.
    """
    request_secret = request.headers.get("X-Internal-Secret", "")
    if not INTERNAL_SECRET or not hmac.compare_digest(request_secret, INTERNAL_SECRET):
        log("auth", "verify_internal_secret", "fail", severity="WARNING")
        raise HTTPException(401, "Invalid internal secret")
    log("auth", "verify_internal_secret", "ok")


# ─── 3. QStash HMAC signature (timeout / activate callbacks) ────

def verify_qstash_signature(request: Request, body: bytes) -> None:
    """
    QStash signs every outgoing request with an HMAC JWT in the
    Upstash-Signature header. The qstash SDK Receiver verifies this
    mathematically against both the current and next signing keys
    (supports key rotation without downtime).
    """
    if os.getenv("QUEUE_MODE", "local") == "local":
        log("auth", "verify_qstash_signature", "bypass_local")
        return
    from qstash import Receiver
    receiver = Receiver(
        current_signing_key=os.getenv("QSTASH_CURRENT_SIGNING_KEY"),
        next_signing_key=os.getenv("QSTASH_NEXT_SIGNING_KEY"),
    )
    try:
        receiver.verify(
            signature=request.headers.get("Upstash-Signature", ""),
            body=body.decode(),
            url=str(request.url),
        )
        log("auth", "verify_qstash_signature", "ok")
    except Exception as e:
        log("auth", "verify_qstash_signature", "fail", error=str(e), severity="WARNING")
        raise HTTPException(401, "Invalid QStash signature")


def verify_qstash_hmac(signature: str, body: bytes) -> bool:
    """
    Lightweight standalone HMAC-SHA256 verification for QStash signatures.
    Does not require the qstash SDK. Returns True if valid, False otherwise.
    """
    key = os.getenv("QSTASH_CURRENT_SIGNING_KEY", "")
    if not key:
        return False
    try:
        hasher = hmac.new(key.encode("utf-8"), body, hashlib.sha256)
        computed_bytes = hasher.digest()
        computed_hex = hasher.hexdigest()

        if hmac.compare_digest(computed_hex, signature):
            return True
        if hmac.compare_digest(computed_hex.lower(), signature.lower()):
            return True

        computed_b64 = base64.b64encode(computed_bytes).decode("utf-8")
        if hmac.compare_digest(computed_b64, signature):
            return True

        computed_b64url = base64.urlsafe_b64encode(computed_bytes).decode("utf-8").rstrip("=")
        sig_clean = signature.rstrip("=")
        if hmac.compare_digest(computed_b64url, sig_clean):
            return True

        return False
    except Exception:
        return False


# ─── 4. Admin (Firebase Custom Claims) ──────────────────────────

def verify_admin(request: Request) -> dict:
    """
    Decode the standard Firebase JWT and assert admin: True custom claim.
    Set the claim once on your founder account:
      firebase_admin.auth.set_custom_user_claims(YOUR_UID, {"admin": True})
    No static secret involved. Cryptographically bound to your Firebase account.
    """
    auth_header = request.headers.get("X-Forwarded-Authorization")
    if not auth_header:
        auth_header = request.headers.get("Authorization", "")
    token_data = verify_token(auth_header)
    if not token_data.get("admin"):
        log("auth", "verify_admin", "denied", uid=token_data.get("uid"), severity="WARNING")
        raise HTTPException(403, "Admin access required")
    log("auth", "verify_admin", "granted", uid=token_data["uid"])
    return token_data


def verify_admin_claim(decoded_token: dict) -> bool:
    """
    Standalone admin claim check on an already-decoded token dict.
    Raises HTTPException 403 if not admin.
    """
    if decoded_token.get("admin") is not True:
        raise HTTPException(403, "Admin access required")
    return True
