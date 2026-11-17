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


def normalize_phone_e164(phone: Optional[str], default_country_code: str = "+91") -> str:
    """
    Strict E.164 Phone Number Normalization.
    Transforms raw inputs into canonical international format:
      '9876543210' -> '+919876543210'
      '09876543210' -> '+919876543210'
      '+91 98765 43210' -> '+919876543210'
      '919876543210' -> '+919876543210'
    Raises ValueError on invalid numbers.
    """
    if not phone:
        raise ValueError("Phone number is required")

    raw = str(phone).strip()
    # Remove whitespace, parentheses, dashes
    cleaned = re.sub(r"[\s\-\(\)]", "", raw)

    if cleaned.startswith("+"):
        digits_only = re.sub(r"[^0-9]", "", cleaned)
        if len(digits_only) < 10 or len(digits_only) > 15:
            raise ValueError(f"Invalid international phone number length: {cleaned}")
        return f"+{digits_only}"

    digits = re.sub(r"[^0-9]", "", cleaned)

    # 10-digit standard Indian mobile
    if len(digits) == 10:
        if default_country_code == "+91" and digits[0] not in "6789":
            raise ValueError(f"Invalid Indian mobile number prefix: '{digits}'")
        return f"{default_country_code}{digits}"

    # 11-digit with leading 0 (STD trunk dial)
    if len(digits) == 11 and digits.startswith("0"):
        national = digits[1:]
        if default_country_code == "+91" and national[0] not in "6789":
            raise ValueError(f"Invalid Indian mobile number prefix: '{national}'")
        return f"{default_country_code}{national}"

    # 12-digit starting with 91
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"

    if 10 <= len(digits) <= 15:
        return f"+{digits}"

    raise ValueError(f"Cannot normalize phone number: '{phone}'")

