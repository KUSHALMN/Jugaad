from core.config import settings
import logging

logger = logging.getLogger(__name__)

class SMSService:
    async def send_otp(self, phone: str, otp: str) -> bool:
        if settings.SMS_MODE == "fake":
            # Print OTP to console — copy paste for testing
            print(f"""
+----------------------------------+
|     FAKE SMS (LOCAL DEV)         |
|  Phone : {phone}
|  OTP   : {otp}
|  (No real SMS sent)              |
+----------------------------------+
            """)
            logger.info(f"FAKE SMS -> {phone}: OTP = {otp}")
            return True
        else:
            # Real MSG91 call placeholder or implementation
            return await self._send_real_sms(phone, otp)
    
    async def _send_real_sms(self, phone: str, otp: str) -> bool:
        # MSG91 implementation here
        logger.warning("Real SMS requested but MSG91 integration is not fully configured.")
        return False

sms_service = SMSService()
