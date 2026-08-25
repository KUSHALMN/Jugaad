import redis.asyncio as redis
import json
import asyncio
from core.config import settings
import logging

logger = logging.getLogger(__name__)

class LocalQueueService:
    def __init__(self):
        self.redis = redis.from_url(settings.REDIS_URL, decode_responses=True)
    
    async def publish_job(self, queue_name: str, payload: dict) -> str:
        """Push job to local Redis queue"""
        job_id = payload.get("job_id", "unknown")
        await self.redis.lpush(
            f"queue:{queue_name}",
            json.dumps(payload)
        )
        logger.info(f"📥 Job queued → {queue_name}: {job_id}")
        return job_id
    
    async def consume_job(self, queue_name: str) -> dict | None:
        """Pop job from local Redis queue"""
        result = await self.redis.brpop(
            f"queue:{queue_name}", 
            timeout=1
        )
        if result:
            _, data = result
            return json.loads(data)
        return None

    async def set_with_ttl(self, key: str, value: str, ttl: int):
        await self.redis.setex(key, ttl, value)
    
    async def get(self, key: str) -> str | None:
        return await self.redis.get(key)
    
    async def delete(self, key: str):
        await self.redis.delete(key)

    async def keys(self, pattern: str) -> list[str]:
        return await self.redis.keys(pattern)

queue_service = LocalQueueService()
