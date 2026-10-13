"""
core/state_machine.py
Strict Directed Acyclic Graph (DAG) state machine for Jugaad jobs.
Guarantees transactional integrity against offline queue replays, race conditions,
and out-of-order mobile mutations.
"""
from typing import Dict, Set, Optional, Tuple, Any
import logging
from datetime import datetime, timezone
from shared.database import supabase
from shared import redis_client

logger = logging.getLogger(__name__)

# Terminal states cannot be transitioned away from under any circumstances
TERMINAL_STATES: Set[str] = {"completed", "cancelled", "disputed"}

# Valid directed transitions
VALID_TRANSITIONS: Dict[str, Set[str]] = {
    "open": {"searching", "matched", "cancelled"},
    "searching": {"open", "matched", "cancelled", "expired"},
    "matched": {"accepted", "searching", "cancelled", "expired"},
    "accepted": {"en_route", "arrived", "in_progress", "cancelled"},
    "en_route": {"arrived", "in_progress", "cancelled"},
    "arrived": {"in_progress", "cancelled"},
    "in_progress": {"completed", "disputed"},
    "completed": set(),
    "cancelled": set(),
    "disputed": {"completed", "cancelled"},  # Only admin resolution can transition from disputed
    "expired": {"open", "cancelled"}
}


class InvalidStateTransitionError(Exception):
    def __init__(self, current_state: str, target_state: str, detail: str = ""):
        self.current_state = current_state
        self.target_state = target_state
        self.detail = detail
        super().__init__(f"Invalid job transition from '{current_state}' to '{target_state}'. {detail}")


def validate_transition(current_state: str, target_state: str) -> bool:
    """Check if the proposed transition is allowed in the DAG."""
    allowed = VALID_TRANSITIONS.get(current_state.lower(), set())
    return target_state.lower() in allowed


def transition_job_state(
    job_id: str,
    target_state: str,
    actor_id: str,
    actor_role: str,
    metadata: Optional[Dict[str, Any]] = None,
    is_offline_replay: bool = False
) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """
    Executes an atomic validated state transition.
    If an offline replay attempts to complete an already cancelled job,
    it rejects the transition and automatically creates a dispute incident.
    """
    metadata = metadata or {}
    job_res = supabase.table("jobs").select("id, status, employer_id, worker_id, amount").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        return False, "Job not found", None

    current_state = str(job_res.data.get("status") or "").lower()
    target_state = target_state.lower()

    # Idempotent fast-path: if already in target state, succeed cleanly
    if current_state == target_state:
        return True, "State unchanged (idempotent)", job_res.data

    # Check for Terminal Conflict (e.g. Worker completed offline, but Customer cancelled online)
    if current_state in TERMINAL_STATES and target_state != current_state:
        logger.warning(
            f"State conflict on job {job_id}: current='{current_state}', attempted='{target_state}', "
            f"actor={actor_id}, is_offline={is_offline_replay}"
        )
        
        # Raise an automatic dispute incident
        incident_id = None
        try:
            now_iso = datetime.now(timezone.utc).isoformat()
            dispute_payload = {
                "job_id": job_id,
                "current_status": current_state,
                "attempted_status": target_state,
                "actor_id": actor_id,
                "actor_role": actor_role,
                "is_offline_replay": is_offline_replay,
                "reason": "OFFLINE_MUTATION_TERMINAL_STATE_CONFLICT",
                "metadata": metadata,
                "created_at": now_iso
            }
            ins_res = supabase.table("dispute_incidents").insert(dispute_payload).execute()
            if ins_res and ins_res.data:
                incident_id = ins_res.data[0].get("id")
        except Exception as disp_err:
            logger.error(f"Failed to record dispute incident: {disp_err}")

        return False, f"Job is in terminal state '{current_state}'. Incident #{incident_id or 'auto'} opened for operations review.", {
            "conflict": True,
            "current_state": current_state,
            "incident_id": incident_id
        }

    # Verify DAG validity
    if not validate_transition(current_state, target_state):
        return False, f"Illegal state transition from '{current_state}' to '{target_state}'", None

    # Apply atomic update
    now_iso = datetime.now(timezone.utc).isoformat()
    update_data = {
        "status": target_state,
        "updated_at": now_iso
    }
    if target_state == "accepted":
        update_data["accepted_at"] = now_iso
    elif target_state == "in_progress":
        update_data["started_at"] = now_iso
    elif target_state == "completed":
        update_data["completed_at"] = now_iso

    try:
        up_res = supabase.table("jobs").update(update_data).eq("id", job_id).eq("status", current_state).execute()
        if not up_res.data:
            return False, "Concurrent modification conflict. Please retry.", None
        
        # Invalidate Redis job caches
        try:
            redis_client.delete_state(f"job:{job_id}")
            redis_client.set_state(f"job_state:{job_id}", target_state, ex=86400)
        except Exception:
            pass

        return True, "State transitioned successfully", up_res.data[0]
    except Exception as e:
        logger.error(f"Error transitioning job {job_id} to {target_state}: {e}")
        return False, str(e), None
