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


class BroadcastPayload(BaseModel):
    title: str
    body: str
    target: Optional[str] = "all"  # "all", "workers", "users"


# ── 5. POST /api/v1/admin/broadcast — Dispatch fleet announcements ──────────
@router.post("/broadcast")
def broadcast_admin_notification(
    payload: BroadcastPayload,
    admin_id: str = Depends(verify_admin),
):
    """
    Broadcast system-wide alert from Admin Console to Users and/or Workers.
    Inserts into notifications table and creates audit log.
    """
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        notification_row = {
            "user_id": f"all_{payload.target}",
            "title": payload.title,
            "body": payload.body,
            "type": "ADMIN_BROADCAST",
            "created_at": now_iso,
        }
        try:
            supabase.table("notifications").insert(notification_row).execute()
        except Exception as notif_err:
            logger.warning(f"Broadcast notification insert note: {notif_err}")

        # Audit log
        try:
            supabase.table("admin_log").insert({
                "admin_id": admin_id,
                "action": "ADMIN_BROADCAST",
                "target_table": "notifications",
                "metadata": {
                    "target": payload.target,
                    "title": payload.title,
                    "sent_at": now_iso,
                }
            }).execute()
        except Exception:
            pass

        return {
            "status": "success",
            "message": f"Broadcast dispatched to {payload.target}",
            "broadcast": notification_row,
        }
    except Exception as e:
        logger.error(f"Error dispatching broadcast: {e}")
        raise HTTPException(status_code=500, detail=f"Broadcast failed: {str(e)}")


# ── 6. GET /api/v1/admin/jobs — List platform jobs for admin ────────────────
@router.get("/jobs")
def list_jobs_for_admin(
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    admin_id: str = Depends(verify_admin),
):
    """
    List all platform jobs for admin oversight with pagination and status filtering.
    """
    try:
        query = supabase.table("jobs").select("*", count="exact")
        if status and status != "all":
            query = query.eq("status", status)

        start = (page - 1) * limit
        end = start + limit - 1
        res = query.range(start, end).order("created_at", desc=True).execute()

        jobs_data = res.data or []
        total_count = res.count if res.count is not None else len(jobs_data)

        # Collect user and worker IDs to enrich data
        user_ids = list({j["employer_id"] for j in jobs_data if j.get("employer_id")})
        worker_ids = list({j["worker_id"] for j in jobs_data if j.get("worker_id")})

        user_map = {}
        if user_ids:
            try:
                u_res = supabase.table("users").select("id, name, phone").in_("id", user_ids).execute()
                for u in (u_res.data or []):
                    user_map[u["id"]] = u
            except Exception:
                pass

        worker_map = {}
        if worker_ids:
            try:
                w_res = supabase.table("workers").select("id, name, phone, work_category").in_("id", worker_ids).execute()
                for w in (w_res.data or []):
                    worker_map[w["id"]] = w
            except Exception:
                pass

        enriched = []
        for j in jobs_data:
            c = user_map.get(j.get("employer_id")) or {}
            w = worker_map.get(j.get("worker_id")) or {}
            enriched.append({
                **j,
                "customer_name": c.get("name") or "Customer",
                "customer_phone": c.get("phone") or "",
                "worker_name": w.get("name") or ("Assigned Worker" if j.get("worker_id") else None),
                "worker_phone": w.get("phone") or "",
            })

        return {
            "total": total_count,
            "page": page,
            "limit": limit,
            "jobs": enriched,
        }
    except Exception as e:
        logger.error(f"Error listing jobs for admin: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list jobs: {str(e)}")


# ── 7. POST /api/v1/admin/jobs/{job_id}/cancel — Admin override cancel ───────
@router.post("/jobs/{job_id}/cancel")
def admin_cancel_job(
    job_id: str,
    reason: Optional[str] = Query("Cancelled by Admin Operations Console"),
    admin_id: str = Depends(verify_admin),
):
    """
    Admin override: Cancel any job, release assigned worker, update bookings, and notify parties.
    """
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
        if not job_res or not job_res.data:
            raise HTTPException(status_code=404, detail="Job not found")

        job = job_res.data
        new_payment_status = "refunded" if job.get("payment_status") == "paid" else "cancelled"

        # Update job
        supabase.table("jobs").update({
            "status": "cancelled",
            "payment_status": new_payment_status,
            "updated_at": now_iso,
            "notes": reason,
        }).eq("id", job_id).execute()

        # Update bookings
        try:
            supabase.table("bookings").update({"status": "cancelled"}).eq("job_id", job_id).execute()
        except Exception:
            pass

        # Release worker if assigned
        worker_id = job.get("worker_id")
        if worker_id:
            try:
                supabase.table("workers").update({
                    "is_available": True,
                    "is_online": True,
                    "current_job_id": None,
                    "updated_at": now_iso,
                }).eq("id", worker_id).execute()

                supabase.table("notifications").insert({
                    "user_id": worker_id,
                    "title": "Booking Cancelled by Admin",
                    "body": f"Job #{job_id[:6]} was cancelled by Admin Operations. You are available for new requests.",
                    "type": "JOB_CANCELLED_BY_ADMIN",
                    "created_at": now_iso,
                }).execute()
            except Exception as w_err:
                logger.warning(f"Worker release warning: {w_err}")

        # Notify customer
        customer_id = job.get("employer_id") or job.get("user_id")
        if customer_id:
            try:
                supabase.table("notifications").insert({
                    "user_id": customer_id,
                    "title": "Job Cancelled & Refunded",
                    "body": f"Job #{job_id[:6]} was cancelled by Admin. Any prepaid fees have been refunded.",
                    "type": "JOB_CANCELLED_BY_ADMIN",
                    "created_at": now_iso,
                }).execute()
            except Exception as c_err:
                logger.warning(f"Customer notify warning: {c_err}")

        # Audit log
        try:
            supabase.table("admin_log").insert({
                "admin_id": admin_id,
                "action": "JOB_CANCELLED",
                "target_id": job_id,
                "target_table": "jobs",
                "metadata": {"reason": reason, "cancelled_at": now_iso},
            }).execute()
        except Exception:
            pass

        return {
            "status": "success",
            "message": "Job cancelled and worker released successfully.",
            "job_id": job_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error cancelling job {job_id} by admin: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to cancel job: {str(e)}")


class UserStatusPayload(BaseModel):
    is_suspended: bool
    reason: Optional[str] = None


# ── 8. GET /api/v1/admin/users — List registered users with booking metrics ──
@router.get("/users")
def list_users_for_admin(
    role: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    admin_id: str = Depends(verify_admin),
):
    """
    List all platform users for admin monitoring enriched with booking stats,
    cancellation rates, and account status.
    """
    try:
        query = supabase.table("users").select("*", count="exact")
        if role and role != "all":
            query = query.eq("role", role)

        start = (page - 1) * limit
        end = start + limit - 1
        res = query.range(start, end).order("created_at", desc=True).execute()

        raw_users = res.data or []
        total_count = res.count if res.count is not None else len(raw_users)

        # Filter by search string if provided
        if search and search.strip():
            s = search.strip().lower()
            raw_users = [
                u for u in raw_users
                if s in (u.get("name") or "").lower()
                or s in (u.get("phone") or "").lower()
                or s in (u.get("email") or "").lower()
                or s in (u.get("id") or "").lower()
            ]

        # Aggregate booking metrics for each user
        user_ids = [u["id"] for u in raw_users if u.get("id")]
        stats_map = {}
        if user_ids:
            try:
                jobs_res = supabase.table("jobs").select("employer_id, status, amount, surcharge_amount").in_("employer_id", user_ids).execute()
                for j in (jobs_res.data or []):
                    uid = j.get("employer_id")
                    if not uid:
                        continue
                    if uid not in stats_map:
                        stats_map[uid] = {
                            "total_bookings": 0,
                            "completed_bookings": 0,
                            "cancelled_bookings": 0,
                            "total_spent": 0.0,
                        }
                    stats_map[uid]["total_bookings"] += 1
                    status = (j.get("status") or "").lower()
                    if status == "completed":
                        stats_map[uid]["completed_bookings"] += 1
                        val = float(j.get("amount") or 0.0) + float(j.get("surcharge_amount") or 0.0)
                        stats_map[uid]["total_spent"] += val
                    elif status == "cancelled":
                        stats_map[uid]["cancelled_bookings"] += 1
            except Exception as j_err:
                logger.warning(f"Failed to aggregate user job stats: {j_err}")

        enriched = []
        for u in raw_users:
            uid = u.get("id")
            s = stats_map.get(uid, {
                "total_bookings": 0,
                "completed_bookings": 0,
                "cancelled_bookings": 0,
                "total_spent": 0.0,
            })
            total_b = s["total_bookings"]
            canc_b = s["cancelled_bookings"]
            canc_rate = round((canc_b / total_b * 100), 1) if total_b > 0 else 0.0
            is_susp = bool(u.get("is_suspended") or u.get("is_banned") or u.get("status") == "suspended")

            enriched.append({
                "id": str(uid),
                "name": u.get("name") or "User",
                "phone": u.get("phone") or "",
                "email": u.get("email") or "",
                "role": u.get("role") or "employer",
                "created_at": u.get("created_at"),
                "total_bookings": total_b,
                "completed_bookings": s["completed_bookings"],
                "cancelled_bookings": canc_b,
                "cancellation_rate": canc_rate,
                "total_spent": round(s["total_spent"], 2),
                "is_suspended": is_susp,
                "status": "suspended" if is_susp else "active",
            })

        return {
            "total": total_count,
            "page": page,
            "limit": limit,
            "users": enriched,
        }
    except Exception as e:
        logger.error(f"Error listing users for admin: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list users: {str(e)}")


# ── 9. POST /api/v1/admin/users/{user_id}/status — Suspend or reactivate user ─
@router.post("/users/{user_id}/status")
def update_user_status_by_admin(
    user_id: str,
    payload: UserStatusPayload,
    admin_id: str = Depends(verify_admin),
):
    """
    Suspend, ban, or reactivate a customer account with audit logging.
    """
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        new_status = "suspended" if payload.is_suspended else "active"

        # Update users table
        up_data = {
            "is_suspended": payload.is_suspended,
            "is_banned": payload.is_suspended,
            "status": new_status,
        }
        supabase.table("users").update(up_data).eq("id", user_id).execute()

        # Audit log
        try:
            supabase.table("admin_log").insert({
                "admin_id": admin_id,
                "action": "USER_STATUS_UPDATE",
                "target_id": user_id,
                "target_table": "users",
                "metadata": {
                    "is_suspended": payload.is_suspended,
                    "reason": payload.reason,
                    "updated_at": now_iso,
                }
            }).execute()
        except Exception:
            pass

        return {
            "status": "success",
            "message": f"User status updated to {new_status}",
            "user_id": user_id,
            "is_suspended": payload.is_suspended,
        }
    except Exception as e:
        logger.error(f"Error updating user status: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update user status: {str(e)}")


# ── 10. GET /api/v1/admin/analytics/summary — Operational & financial analytics
@router.get("/analytics/summary")
def get_analytics_summary_for_admin(
    days: int = Query(7, ge=1, le=90),
    admin_id: str = Depends(verify_admin),
):
    """
    Provides multi-day operational metrics, revenue breakdowns, platform commission,
    and fulfillment statistics for SaaS dashboards and reports.
    """
    try:
        from datetime import timedelta
        now = datetime.now(timezone.utc)
        start_date = (now - timedelta(days=days)).isoformat()

        # Fetch recent jobs
        jobs_res = supabase.table("jobs").select(
            "id, status, amount, surcharge_amount, job_type, created_at, accepted_at, completed_at"
        ).gte("created_at", start_date).order("created_at", desc=False).execute()

        jobs = jobs_res.data or []
        total_jobs = len(jobs)
        completed_jobs = [j for j in jobs if j.get("status") == "completed"]
        cancelled_jobs = [j for j in jobs if j.get("status") == "cancelled"]

        total_gmv = sum(
            float(j.get("amount") or 0.0) + float(j.get("surcharge_amount") or 0.0)
            for j in completed_jobs
        )
        platform_commission = round(total_gmv * 0.10, 2)  # 10% platform take rate
        fulfillment_rate = round((len(completed_jobs) / total_jobs * 100), 1) if total_jobs > 0 else 0.0

        # Build daily time-series buckets
        daily_map = {}
        for i in range(days):
            d_str = (now - timedelta(days=days - 1 - i)).strftime("%b %d")
            daily_map[d_str] = {
                "date": d_str,
                "jobs": 0,
                "completed": 0,
                "cancelled": 0,
                "gmv": 0.0,
                "commission": 0.0,
            }

        for j in jobs:
            c_at = j.get("created_at")
            if not c_at:
                continue
            try:
                d_key = datetime.fromisoformat(c_at.replace("Z", "+00:00")).strftime("%b %d")
                if d_key in daily_map:
                    daily_map[d_key]["jobs"] += 1
                    if j.get("status") == "completed":
                        daily_map[d_key]["completed"] += 1
                        val = float(j.get("amount") or 0.0) + float(j.get("surcharge_amount") or 0.0)
                        daily_map[d_key]["gmv"] = round(daily_map[d_key]["gmv"] + val, 2)
                        daily_map[d_key]["commission"] = round(daily_map[d_key]["commission"] + (val * 0.10), 2)
                    elif j.get("status") == "cancelled":
                        daily_map[d_key]["cancelled"] += 1
            except Exception:
                pass

        time_series = list(daily_map.values())

        return {
            "period_days": days,
            "total_jobs": total_jobs,
            "completed_jobs": len(completed_jobs),
            "cancelled_jobs": len(cancelled_jobs),
            "fulfillment_rate": fulfillment_rate,
            "total_gmv": round(total_gmv, 2),
            "platform_commission": platform_commission,
            "time_series": time_series,
        }
    except Exception as e:
        logger.error(f"Error computing analytics summary: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to compute analytics: {str(e)}")

