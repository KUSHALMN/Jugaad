# services/notification_service/email_service.py
"""
SMTP email sender for dev/pilot — replaces SMS via MSG91.
Uses Gmail App Password for authentication.
"""
import smtplib
import os
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logger = logging.getLogger("email_service")

EMAIL_USER = os.getenv("EMAIL_USER", "")
EMAIL_PASS = os.getenv("EMAIL_PASS", "")
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))


def send_email(to: str, subject: str, html_body: str) -> bool:
    """
    Send an HTML email via SMTP.
    Returns True on success, False on failure (never raises).
    """
    if not EMAIL_USER or not EMAIL_PASS:
        logger.warning("EMAIL_USER or EMAIL_PASS not set — skipping email")
        return False

    if not to:
        logger.warning("No recipient email — skipping")
        return False

    msg = MIMEMultipart("alternative")
    msg["From"] = f"Jugaad <{EMAIL_USER}>"
    msg["To"] = to
    msg["Subject"] = subject
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(EMAIL_USER, EMAIL_PASS)
            server.send_message(msg)
        logger.info(f"Email sent to {to} | subject={subject}")
        return True
    except smtplib.SMTPAuthenticationError:
        logger.error("SMTP auth failed — check EMAIL_USER / EMAIL_PASS (use App Password)")
        return False
    except smtplib.SMTPException as e:
        logger.error(f"SMTP error sending to {to}: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected email error: {e}")
        return False
