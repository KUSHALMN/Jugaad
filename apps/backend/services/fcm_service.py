import logging
from firebase_admin import messaging
from shared.database import supabase

logger = logging.getLogger(__name__)

class FCMService:
    async def send_job_request(self, worker_id: str, data: dict):
        try:
            res = supabase.table("users").select("fcm_token").eq("id", worker_id).execute()
            if not res.data or not res.data[0].get("fcm_token"):
                logger.warning(f"No FCM token found for worker {worker_id}")
                return False
            fcm_token = res.data[0]["fcm_token"]
            
            is_emergency = data.get("is_emergency") == "True"
            if is_emergency:
                skill_title = data.get('job_type', 'Service').replace('_', ' ').title()
                title = f"🚨 Emergency {skill_title} Request"
                body = "Customer nearby requires immediate assistance."
            else:
                title = "New Job Request"
                body = f"New request for {data.get('job_type', 'service').replace('_', ' ').title()}"

            message = messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={k: str(v) for k, v in data.items()},
                android=messaging.AndroidConfig(
                    priority="high",
                    ttl=int(data.get("timeout_seconds", 30))
                )
            )
            resp = messaging.send(message)
            logger.info(f"FCM sent to worker {worker_id}: {resp}")
            return True
        except Exception as e:
            logger.error(f"Failed to send FCM to worker {worker_id}: {e}")
            return False

    async def send_silent_fcm(self, token: str, data: dict):
        try:
            if not token:
                return False
            message = messaging.Message(
                token=token,
                data={k: str(v) for k, v in data.items()},
                android=messaging.AndroidConfig(priority="high"),
            )
            resp = messaging.send(message)
            logger.info(f"Silent FCM sent: {resp}")
            return True
        except Exception as e:
            logger.error(f"Failed to send silent FCM: {e}")
            return False

    async def send_no_worker_found(self, user_id: str, job_id: str):
        try:
            res = supabase.table("users").select("fcm_token").eq("id", user_id).execute()
            if not res.data or not res.data[0].get("fcm_token"):
                logger.warning(f"No FCM token found for user {user_id}")
                return False
            fcm_token = res.data[0]["fcm_token"]
            
            message = messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(
                    title="No Worker Found",
                    body="We couldn't find a worker for your request. Please try again.",
                ),
                data={
                    "type": "NO_WORKER_FOUND",
                    "job_id": job_id
                }
            )
            resp = messaging.send(message)
            logger.info(f"FCM sent to user {user_id}: {resp}")
            return True
        except Exception as e:
            logger.error(f"Failed to send FCM to user {user_id}: {e}")
            return False

    async def send_notification(self, user_id: str, title: str, body: str, data: dict = None) -> bool:
        try:
            res = supabase.table("users").select("fcm_token").eq("id", user_id).execute()
            if not res.data or not res.data[0].get("fcm_token"):
                logger.warning(f"No FCM token found for user {user_id}")
                return False
            fcm_token = res.data[0]["fcm_token"]

            message_data = {k: str(v) for k, v in data.items()} if data else {}

            message = messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=message_data,
                android=messaging.AndroidConfig(
                    priority="high"
                )
            )
            resp = messaging.send(message)
            logger.info(f"FCM notification sent to user {user_id}: {resp}")
            return True
        except Exception as e:
            logger.error(f"Failed to send FCM notification to user {user_id}: {e}")
            return False

fcm_service = FCMService()

