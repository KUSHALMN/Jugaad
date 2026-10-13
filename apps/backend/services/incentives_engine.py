"""
services/incentives_engine.py
Supply-Side Retention & Daily Minimum Earnings Guarantee Engine for Jugaad.
Calculates active hours, on-duty completion rates, and daily top-up bonuses
to prevent worker churn during initial pilot launch in Tier-2/3 cities.
"""
from typing import Dict, Any, List
import time
import logging
from datetime import datetime, timezone
from shared.database import supabase
from shared import redis_client

logger = logging.getLogger(__name__)

# Daily incentive tiers for verified partners
GUARANTEE_TIERS = [
    {"min_hours": 4.0, "min_acceptance_rate": 0.85, "guaranteed_floor": 400.0},
    {"min_hours": 8.0, "min_acceptance_rate": 0.90, "guaranteed_floor": 900.0},
]


class IncentivesEngine:
    @staticmethod
    def calculate_surge_multiplier(weather_condition: str = "clear", active_demand_ratio: float = 1.0) -> float:
        """
        Calculates localized surge pricing multiplier.
        Monsoon rain / festival rush dynamically increases worker pay.
        """
        multiplier = 1.0
        if weather_condition.lower() in ["rain", "monsoon", "thunderstorm"]:
            multiplier += 0.25
        if active_demand_ratio > 1.5:
            multiplier += 0.20
        return min(round(multiplier, 2), 1.50)

    @classmethod
    def evaluate_daily_guarantee(cls, worker_id: str, date_str: str) -> Dict[str, Any]:
        """
        Evaluates worker's daily eligibility for platform top-up guarantee.
        If worker stood by for 4+ hours and actual earnings < ₹400, platform tops up the gap.
        """
        # Fetch completed jobs and earnings for this worker on this date
        try:
            jobs_res = (supabase.table("jobs")
                .select("amount, payment_status, created_at")
                .eq("worker_id", worker_id)
                .eq("status", "completed")
                .execute())
            jobs = jobs_res.data or []
        except Exception:
            jobs = []

        actual_earnings = sum(float(j.get("amount") or 0.0) for j in jobs)

        # Retrieve tracked on-duty seconds from Redis
        cached_seconds = redis_client.get_state(f"worker:duty_seconds:{worker_id}:{date_str}")
        duty_seconds = float(cached_seconds) if cached_seconds else 14400.0  # default 4 hours in dev
        duty_hours = round(duty_seconds / 3600.0, 2)

        # Match eligible tier
        qualified_tier = None
        for tier in sorted(GUARANTEE_TIERS, key=lambda t: t["min_hours"], reverse=True):
            if duty_hours >= tier["min_hours"]:
                qualified_tier = tier
                break

        guaranteed_floor = qualified_tier["guaranteed_floor"] if qualified_tier else 0.0
        top_up_bonus = max(0.0, round(guaranteed_floor - actual_earnings, 2))

        return {
            "worker_id": worker_id,
            "date": date_str,
            "on_duty_hours": duty_hours,
            "completed_jobs_count": len(jobs),
            "actual_earnings": actual_earnings,
            "guaranteed_floor": guaranteed_floor,
            "top_up_bonus": top_up_bonus,
            "is_eligible_for_top_up": top_up_bonus > 0.0
        }
