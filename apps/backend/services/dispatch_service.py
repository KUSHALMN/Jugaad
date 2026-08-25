import asyncio
import json
from services.queue_service import queue_service
from services.fcm_service import fcm_service
from shared.database import supabase
import logging

logger = logging.getLogger(__name__)

class DispatchService:
    
    async def start_dispatch(self, job_id: str, user_id: str, 
                              lat: float, lng: float, service_type: str, is_emergency: bool = False):
        """
        Main dispatch loop — Uber/Rapido style
        Expands radius until worker accepts or all rounds exhausted
        """
        logger.info(f"🚀 Dispatch started for job {job_id} ({'EMERGENCY' if is_emergency else 'NORMAL'})")
        
        # Update job status
        await self._update_job_status(job_id, "searching")
        
        dispatched_workers = set()
        
        if is_emergency:
            rounds = [
                {"radius_km": 10, "timeout_sec": 30},
                {"radius_km": 15, "timeout_sec": 30},
                {"radius_km": 20, "timeout_sec": 30},
            ]
        else:
            rounds = [
                {"radius_km": 1, "timeout_sec": 30},
                {"radius_km": 3, "timeout_sec": 30},
                {"radius_km": 5, "timeout_sec": 30},
            ]
        
        for round_num, round_config in enumerate(rounds, 1):
            radius = round_config["radius_km"]
            timeout = round_config["timeout_sec"]
            
            logger.info(f"🔍 Round {round_num}: Searching {radius}km radius")
            
            # Find nearby available workers
            workers = await self._get_nearby_workers(
                lat, lng, radius, service_type, dispatched_workers, is_emergency
            )
            
            if not workers:
                logger.info(f"No workers found in {radius}km, expanding...")
                continue
            
            # Send FCM to each worker in this round
            for worker in workers:
                worker_id = str(worker["id"])
                dispatched_workers.add(worker_id)
                
                if is_emergency:
                    # Queue override: find any pending normal job requests for this worker and cancel them
                    try:
                        pending_keys = await queue_service.keys(f"job:*:pending:{worker_id}")
                        for p_key in pending_keys:
                            parts = p_key.split(":")
                            if len(parts) >= 2:
                                old_job_id = parts[1]
                                await queue_service.delete(p_key)
                                # Send silent FCM to clear the overlay
                                token = worker.get("fcm_token")
                                if token:
                                    await fcm_service.send_silent_fcm(token, {
                                        "type": "JOB_CANCELLED",
                                        "job_id": old_job_id
                                    })
                                logger.info(f"⚡ Overrode normal job {old_job_id} queue for emergency job {job_id} on worker {worker_id}")
                    except Exception as ex:
                        logger.error(f"Error overriding normal queue for worker {worker_id}: {ex}")

                # Send FCM notification
                await fcm_service.send_job_request(worker_id, {
                    "job_id": job_id,
                    "job_type": service_type,
                    "user_lat": str(lat),
                    "user_lng": str(lng),
                    "timeout_seconds": str(timeout),
                    "is_emergency": str(is_emergency)
                })
                
                # Store pending request in Redis (TTL = timeout)
                await queue_service.set_with_ttl(
                    f"job:{job_id}:pending:{worker_id}",
                    "SENT",
                    timeout
                )
                
                logger.info(f"📤 FCM sent to worker {worker_id}")
            
            # Wait for acceptance
            accepted = await self._wait_for_acceptance(job_id, timeout)
            
            if accepted:
                logger.info(f"✅ Job {job_id} accepted!")
                return True
        
        # No worker accepted after all rounds
        # Check if job was already accepted (avoid overwriting status if it was accepted right at the deadline)
        status = await queue_service.get(f"job:{job_id}:status")
        if status == "ACCEPTED":
            logger.info(f"✅ Job {job_id} accepted in the final seconds!")
            return True
            
        await self._update_job_status(job_id, "no_worker_found")
        await fcm_service.send_no_worker_found(user_id, job_id)
        logger.info(f"❌ No worker found for job {job_id}")
        return False
    
    async def _wait_for_acceptance(self, job_id: str, timeout: int) -> bool:
        """Poll Redis every 2s to check if job was accepted"""
        elapsed = 0
        while elapsed < timeout:
            status = await queue_service.get(f"job:{job_id}:status")
            if status == "ACCEPTED":
                return True
            await asyncio.sleep(2)
            elapsed += 2
        return False
    
    async def handle_worker_response(self, job_id: str, worker_id: str, 
                                      response: str):
        """Called when worker accepts or rejects"""
        if response == "ACCEPT":
            # Set accepted status
            await queue_service.set_with_ttl(
                f"job:{job_id}:status", "ACCEPTED", 3600
            )
            await self._update_job_status(job_id, "accepted")
            await self._assign_worker(job_id, worker_id)
            
            # Cancel other pending requests
            await self._cancel_other_requests(job_id, worker_id)
            
            logger.info(f"✅ Worker {worker_id} accepted job {job_id}")
        else:
            # Worker rejected
            await queue_service.delete(
                f"job:{job_id}:pending:{worker_id}"
            )
            logger.info(f"❌ Worker {worker_id} rejected job {job_id}")
    
    async def _get_nearby_workers(self, lat, lng, radius_km, 
                                   service_type, exclude_ids, is_emergency: bool = False):
        """PostGIS query for nearby available workers"""
        exclude_list = list(exclude_ids) if exclude_ids else ["none"]
        if not exclude_list:
            exclude_list = ["none"]
        
        try:
            result = supabase.rpc("get_nearby_workers", {
                "user_lat": lat,
                "user_lng": lng,
                "radius_meters": radius_km * 1000,
                "service_type": service_type,
                "exclude_worker_ids": exclude_list,
                "p_is_emergency": is_emergency
            }).execute()
            return result.data or []
        except Exception as e:
            logger.error(f"Error querying nearby workers RPC: {e}")
            # Fallback to basic query if RPC function isn't created/ready in local db
            try:
                query = supabase.table("workers").select("id").eq("is_available", True)
                if is_emergency:
                    query = query.eq("emergency_available", True)
                fallback_result = query.execute()
                workers = fallback_result.data or []
                ret_workers = []
                for w in workers:
                    w_id = str(w["id"])
                    if w_id not in exclude_list:
                        token_res = supabase.table("users").select("fcm_token").eq("id", w_id).execute()
                        token = token_res.data[0]["fcm_token"] if token_res.data else ""
                        ret_workers.append({"id": w_id, "fcm_token": token})
                return ret_workers[:10]
            except Exception as e2:
                logger.error(f"Fallback query error: {e2}")
                return []
    
    async def _update_job_status(self, job_id: str, status: str):
        supabase.table("jobs").update(
            {"status": status}
        ).eq("id", job_id).execute()
    
    async def _assign_worker(self, job_id: str, worker_id: str):
        # Resolve internal UUID for the worker if needed
        res = supabase.table("users").select("id").eq("firebase_uid", worker_id).execute()
        internal_worker_id = res.data[0]["id"] if res.data else worker_id

        supabase.table("jobs").update({
            "worker_id": internal_worker_id,
            "status": "accepted",
            "accepted_at": asyncio.get_event_loop().time() # Fallback local timestamp
        }).eq("id", job_id).execute()
        
        # Mark worker unavailable
        supabase.table("workers").update({
            "is_available": False
        }).eq("id", internal_worker_id).execute()
    
    async def _cancel_other_requests(self, job_id: str, accepted_worker_id: str):
        # Optional: update other request statuses if a table tracks them
        pass

dispatch_service = DispatchService()
