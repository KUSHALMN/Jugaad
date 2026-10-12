"""
utils/security.py
Enterprise Security & Compliance Utilities for Jugaad.

Implements UIDAI-compliant Aadhaar masking and timing-attack-safe cryptographic verification.
"""
import hmac
import re
from typing import Optional


def mask_aadhaar(val: Optional[str]) -> str:
    """
    UIDAI Compliant Aadhaar Masking.
    Never stores or displays full 12-digit Aadhaar in plain-text.
    Transforms '123456789012' or '1234-5678-9012' -> 'XXXX-XXXX-9012'.
    """
    if not val:
        return "XXXX-XXXX-XXXX"
    cleaned = re.sub(r"[^0-9]", "", str(val))
    if len(cleaned) == 12:
        last4 = cleaned[-4:]
        return f"XXXX-XXXX-{last4}"
    elif len(cleaned) >= 4:
        last4 = cleaned[-4:]
        return f"XXXX-XXXX-{last4}"
    return "XXXX-XXXX-XXXX"


def mask_phone_in(phone: Optional[str]) -> str:
    """
    Standard Indian mobile phone privacy mask.
    Transforms '+919876543210' -> '+91 98*** ***10'.
    """
    if not phone:
        return "+91 ***** *****"
    digits = re.sub(r"[^0-9]", "", str(phone))
    if digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    if len(digits) == 10:
        return f"+91 {digits[:2]}*** ***{digits[-2:]}"
    return "+91 ***** *****"


def timing_safe_equal(a: Optional[str], b: Optional[str]) -> bool:
    """
    Constant-time string comparison using hmac.compare_digest.
    Guarantees zero information leakage via CPU execution timing side-channels.
    """
    if a is None or b is None:
        return False
    str_a = str(a).strip()
    str_b = str(b).strip()
    return hmac.compare_digest(str_a.encode("utf-8"), str_b.encode("utf-8"))
