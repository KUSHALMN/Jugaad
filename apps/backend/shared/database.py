from core.config import settings
from supabase import create_client, Client

SUPABASE_URL = settings.SUPABASE_URL
SUPABASE_SERVICE_KEY = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_SERVICE_KEY

_supabase_client: Client | None = None


def get_supabase() -> Client:
    """Singleton Supabase client — service role for backend. Lazy-initialized."""
    global _supabase_client
    if _supabase_client is None:
        if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
            raise RuntimeError(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables must be set"
            )
        _supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    return _supabase_client


class _LazySupabase:
    """Lazy proxy — initializes Supabase client on first attribute access, not on import."""

    def __getattr__(self, name):
        return getattr(get_supabase(), name)


# Expose as module-level for convenience — will NOT crash on import
supabase: Client = _LazySupabase()  # type: ignore

# Usage examples (replacing Firestore patterns):
#
# BEFORE: db.collection("jobs").document(job_id).get()
# AFTER:  supabase.table("jobs").select("*").eq("id", job_id).single().execute()
#
# BEFORE: db.collection("workers").where("is_available", "==", True)
# AFTER:  supabase.table("workers").select("*").eq("is_available", True).execute()
#
# BEFORE: doc_ref.set(data)
# AFTER:  supabase.table("jobs").insert(data).execute()
#
# BEFORE: doc_ref.update({"status": "matched"})
# AFTER:  supabase.table("jobs").update({"status": "matched"}).eq("id", job_id).execute()
#
# BEFORE: Firestore transaction
# AFTER:  supabase.rpc("your_postgres_function", params).execute()
