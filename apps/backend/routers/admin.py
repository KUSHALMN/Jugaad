import json
import logging
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from shared.auth import verify_firebase_token, _IS_LOCAL
from shared.database import supabase

logger = logging.getLogger("jugaad.admin")

router = APIRouter()

def verify_admin(request: Request, uid: str = Depends(verify_firebase_token)) -> str:
    """
    FastAPI dependency to verify user has admin privileges.
    Checks users table for role == 'admin' or respects local dev bypass.
    """
    try:
        res = supabase.table("users").select("id, role, firebase_uid").eq("firebase_uid", uid).maybe_single().execute()
        if res and res.data and res.data.get("role") == "admin":
            return res.data["id"]
        
        # Check by id if firebase_uid check didn't match
        res_by_id = supabase.table("users").select("id, role").eq("id", uid).maybe_single().execute()
        if res_by_id and res_by_id.data and res_by_id.data.get("role") == "admin":
            return res_by_id.data["id"]
    except Exception as e:
        logger.warning(f"Error checking admin role for uid {uid}: {e}")

    # Local dev mode fallback if running locally
    if _IS_LOCAL:
        logger.info(f"Local dev mode bypass granted for admin user: {uid}")
        return uid

    raise HTTPException(status_code=403, detail="Not authorized as admin")


class RejectRequest(BaseModel):
    reason: str


# ── 1. GET /api/v1/admin/workers — List pending/all workers ─────────────────
@router.get("/workers")
def list_workers_for_admin(
    status: Optional[str] = Query("pending_approval"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    admin_id: str = Depends(verify_admin),
):
    """
    List workers for admin review filtered by status (pending_approval, approved, rejected, or all).
    """
    try:
        query = supabase.table("workers").select("*", count="exact")

        if status and status != "all":
            # Support both status and legacy approval_status
            if status == "pending_approval":
                query = query.or_("status.eq.pending_approval,status.eq.pending,approval_status.eq.pending_approval,approval_status.eq.pending")
            elif status == "approved":
                query = query.or_("status.eq.approved,approval_status.eq.approved")
            elif status == "rejected":
                query = query.or_("status.eq.rejected,approval_status.eq.rejected")
            else:
                query = query.eq("status", status)

        start = (page - 1) * limit
        end = start + limit - 1
        res = query.range(start, end).order("created_at", desc=True).execute()

        workers_data = res.data or []
        total_count = res.count if res.count is not None else len(workers_data)

        # Enrich worker records with user email/phone
        user_ids = [w["id"] for w in workers_data if w.get("id")]
        user_map = {}
        if user_ids:
            try:
                users_res = supabase.table("users").select("id, name, phone, email, firebase_uid").in_("id", user_ids).execute()
                for u in (users_res.data or []):
                    user_map[u["id"]] = u
            except Exception as u_err:
                logger.warning(f"Failed to fetch user profiles for admin worker list: {u_err}")

        enriched = []
        for w in workers_data:
            w_user = user_map.get(w["id"]) or {}
            w_status = w.get("status") or w.get("approval_status") or "pending_approval"
            enriched.append({
                "id": str(w["id"]),
                "name": w.get("name") or w_user.get("name") or "Worker",
                "phone": w.get("phone") or w_user.get("phone") or "",
                "email": w_user.get("email") or "",
                "work_category": w.get("work_category") or (w.get("skills")[0] if w.get("skills") else "General"),
                "skills": w.get("skills") or [],
                "specialities": w.get("specialities") or [],
                "area": w.get("area") or "Mysuru",
                "status": w_status,
                "approval_status": w_status,
                "rejection_reason": w.get("rejection_reason"),
                "id_document_url": w.get("id_document_url"),
                "documents": w.get("documents") or [],
                "rating": float(w.get("rating") or 0.0),
                "total_jobs": int(w.get("total_jobs") or w.get("totalJobsCompleted") or 0),
                "created_at": w.get("created_at"),
            })

        return {
            "total": total_count,
            "page": page,
            "limit": limit,
            "workers": enriched,
        }
    except Exception as e:
        logger.error(f"Error listing workers for admin: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list workers: {str(e)}")


# ── 2. GET /api/v1/admin/workers/{worker_id} — Single worker detail ─────────
@router.get("/workers/{worker_id}")
def get_worker_detail_for_admin(
    worker_id: str,
    admin_id: str = Depends(verify_admin),
):
    """
    Fetch full detail of a specific worker for admin verification.
    """
    try:
        w_res = supabase.table("workers").select("*").eq("id", worker_id).maybe_single().execute()
        if not w_res or not w_res.data:
            raise HTTPException(status_code=404, detail="Worker not found.")

        w = w_res.data
        u_res = supabase.table("users").select("id, name, phone, email, firebase_uid").eq("id", worker_id).maybe_single().execute()
        u = u_res.data if u_res and u_res.data else {}

        w_status = w.get("status") or w.get("approval_status") or "pending_approval"
        return {
            "id": str(w["id"]),
            "name": w.get("name") or u.get("name") or "Worker",
            "phone": w.get("phone") or u.get("phone") or "",
            "email": u.get("email") or "",
            "work_category": w.get("work_category") or (w.get("skills")[0] if w.get("skills") else "General"),
            "skills": w.get("skills") or [],
            "specialities": w.get("specialities") or [],
            "area": w.get("area") or "Mysuru",
            "status": w_status,
            "approval_status": w_status,
            "rejection_reason": w.get("rejection_reason"),
            "id_document_url": w.get("id_document_url"),
            "documents": w.get("documents") or [],
            "hourly_rate": w.get("hourly_rate") or w.get("rate_per_hour"),
            "experience": w.get("experience"),
            "bio": w.get("bio"),
            "rating": float(w.get("rating") or 0.0),
            "total_jobs": int(w.get("total_jobs") or w.get("totalJobsCompleted") or 0),
            "created_at": w.get("created_at"),
            "approved_at": w.get("approved_at"),
            "approved_by": w.get("approved_by"),
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting worker detail for admin: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch worker detail: {str(e)}")


# ── 3. POST /api/v1/admin/workers/{worker_id}/approve — Approve Worker ──────
@router.post("/workers/{worker_id}/approve")
def approve_worker(
    worker_id: str,
    admin_id: str = Depends(verify_admin),
):
    """
    Approve worker application. Uses the approve_worker RPC (which atomically sets
    status, is_available, is_online etc.) and falls back to direct column updates.
    Sends FCM + in-app notification. Idempotent — won't duplicate notifications.
    """
    try:
        now_iso = datetime.now(timezone.utc).isoformat()

        # ── Idempotency guard: check current status ──
        check = supabase.table("workers").select("id, status, approval_status").eq("id", worker_id).maybe_single().execute()
        if not check or not check.data:
            raise HTTPException(status_code=404, detail="Worker record not found to approve.")

        current_status = (check.data.get("status") or check.data.get("approval_status") or "").lower()
        already_approved = current_status == "approved"

        # ── Primary: Use the approve_worker RPC (handles all existing columns) ──
        rpc_ok = False
        try:
            rpc_res = supabase.rpc("approve_worker", {"p_worker_id": worker_id}).execute()
            rpc_ok = rpc_res.data is True or bool(rpc_res.data)
        except Exception as rpc_err:
            logger.warning(f"approve_worker RPC failed: {rpc_err}")

        # ── Fallback: direct update with only columns known to exist ──
        if not rpc_ok:
            core_update = {
                "status": "approved",
                "approval_status": "approved",
                "is_available": True,
                "is_online": True,
                "updated_at": now_iso,
            }
            up_res = supabase.table("workers").update(core_update).eq("id", worker_id).execute()
            if not up_res.data:
                raise HTTPException(status_code=404, detail="Worker record not found to approve.")

        # ── Try setting extended columns (may not exist yet) ──
        try:
            ext_update = {
                "approved_at": now_iso,
                "approved_by": admin_id,
                "is_active": True,
                "rejection_reason": None,
            }
            supabase.table("workers").update(ext_update).eq("id", worker_id).execute()
        except Exception as ext_err:
            logger.debug(f"Extended approval columns update skipped (columns may not exist): {ext_err}")

        # ── Insert in-app notification (skip if already approved — idempotency) ──
        if not already_approved:
            try:
                supabase.table("notifications").insert({
                    "user_id": worker_id,
                    "title": "Account Approved!",
                    "body": "You're approved! You're now live on Jugaad.",
                    "type": "WORKER_APPROVED",
                    "created_at": now_iso,
                }).execute()
            except Exception as notif_err:
                logger.warning(f"In-app notification insert failed: {notif_err}")

            # ── Send FCM push notification ──
            try:
                from services.fcm_service import fcm_service
                import asyncio
                try:
                    loop = asyncio.get_event_loop()
                    if loop.is_running():
                        loop.create_task(fcm_service.send_notification(
                            user_id=worker_id,
                            title="Account Approved!",
                            body="You're approved! You're now live on Jugaad.",
                            data={"type": "WORKER_APPROVED", "status": "approved"}
                        ))
                    else:
                        loop.run_until_complete(fcm_service.send_notification(
                            user_id=worker_id,
                            title="Account Approved!",
                            body="You're approved! You're now live on Jugaad.",
                            data={"type": "WORKER_APPROVED", "status": "approved"}
                        ))
                except RuntimeError:
                    asyncio.run(fcm_service.send_notification(
                        user_id=worker_id,
                        title="Account Approved!",
                        body="You're approved! You're now live on Jugaad.",
                        data={"type": "WORKER_APPROVED", "status": "approved"}
                    ))
            except Exception as fcm_err:
                logger.warning(f"FCM push notification send error: {fcm_err}")

        # ── Log admin audit record ──
        try:
            supabase.table("admin_log").insert({
                "admin_id": admin_id,
                "action": "WORKER_APPROVED",
                "target_id": worker_id,
                "target_table": "workers",
                "metadata": {"approved_at": now_iso},
            }).execute()
        except Exception as log_err:
            logger.warning(f"Admin log insert failed: {log_err}")

        return {
            "status": "success",
            "message": "Worker approved successfully." if not already_approved else "Worker was already approved.",
            "worker_id": worker_id,
            "already_approved": already_approved,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error approving worker {worker_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to approve worker: {str(e)}")


# ── 4. POST /api/v1/admin/workers/{worker_id}/reject — Reject Worker ────────
@router.post("/workers/{worker_id}/reject")
def reject_worker(
    worker_id: str,
    payload: RejectRequest,
    admin_id: str = Depends(verify_admin),
):
    """
    Reject worker application with reason. Uses reject_worker RPC first, falls back
    to direct update. Sends FCM + in-app notification to worker.
    """
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        reason_text = payload.reason.strip() if payload.reason else "Application criteria not met."

        # ── Check worker exists ──
        check = supabase.table("workers").select("id, status, approval_status").eq("id", worker_id).maybe_single().execute()
        if not check or not check.data:
            raise HTTPException(status_code=404, detail="Worker record not found to reject.")

        # ── Primary: Use the reject_worker RPC ──
        rpc_ok = False
        try:
            rpc_res = supabase.rpc("reject_worker", {"p_worker_id": worker_id}).execute()
            rpc_ok = rpc_res.data is True or bool(rpc_res.data)
        except Exception as rpc_err:
            logger.warning(f"reject_worker RPC failed: {rpc_err}")

        # ── Fallback: direct update with only confirmed-existing columns ──
        if not rpc_ok:
            core_update = {
                "status": "rejected",
                "approval_status": "rejected",
                "is_available": False,
                "is_online": False,
                "updated_at": now_iso,
            }
            up_res = supabase.table("workers").update(core_update).eq("id", worker_id).execute()
            if not up_res.data:
                raise HTTPException(status_code=404, detail="Worker record not found to reject.")

        # ── Try setting extended columns (may not exist yet) ──
        try:
            ext_update = {
                "rejection_reason": reason_text,
                "is_active": False,
            }
            supabase.table("workers").update(ext_update).eq("id", worker_id).execute()
        except Exception as ext_err:
            logger.debug(f"Extended rejection columns update skipped: {ext_err}")

        # Insert in-app notification
        try:
            supabase.table("notifications").insert({
                "user_id": worker_id,
                "title": "Verification Update",
                "body": f"Your worker application was rejected: {reason_text}",
                "type": "WORKER_REJECTED",
                "created_at": now_iso,
            }).execute()
        except Exception as notif_err:
            logger.warning(f"In-app notification insert failed: {notif_err}")

        # Send FCM push notification
        try:
            from services.fcm_service import fcm_service
            import asyncio
            try:
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    loop.create_task(fcm_service.send_notification(
                        user_id=worker_id,
                        title="Verification Update",
                        body=f"Your worker application was rejected: {reason_text}",
                        data={"type": "WORKER_REJECTED", "reason": reason_text}
                    ))
                else:
                    loop.run_until_complete(fcm_service.send_notification(
                        user_id=worker_id,
                        title="Verification Update",
                        body=f"Your worker application was rejected: {reason_text}",
                        data={"type": "WORKER_REJECTED", "reason": reason_text}
                    ))
            except RuntimeError:
                asyncio.run(fcm_service.send_notification(
                    user_id=worker_id,
                    title="Verification Update",
                    body=f"Your worker application was rejected: {reason_text}",
                    data={"type": "WORKER_REJECTED", "reason": reason_text}
                ))
        except Exception as fcm_err:
            logger.warning(f"FCM push notification send error: {fcm_err}")

        # Log admin audit record
        try:
            supabase.table("admin_log").insert({
                "admin_id": admin_id,
                "action": "WORKER_REJECTED",
                "target_id": worker_id,
                "target_table": "workers",
                "metadata": {"reason": reason_text},
            }).execute()
        except Exception as log_err:
            logger.warning(f"Admin log insert failed: {log_err}")

        return {
            "status": "success",
            "message": "Worker rejected.",
            "worker_id": worker_id,
            "reason": reason_text,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error rejecting worker {worker_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to reject worker: {str(e)}")
