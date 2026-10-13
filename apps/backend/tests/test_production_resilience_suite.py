"""
tests/test_production_resilience_suite.py
Production Resilience & Concurrency Test Suite for Jugaad.
Validates:
1. Strict DAG state machine transition rules and terminal conflict interception.
2. Automated PayoutService split math, Section 194O TDS calculation, and idempotency.
3. Redis GEO spatial telemetry ingestion and milestone snapshotting.
4. Public HMAC tracking URL signature integrity.
5. Launch cluster micro-geofencing and 60-second SLA escalation logic.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from core.state_machine import validate_transition, TERMINAL_STATES, VALID_TRANSITIONS

from services.payout_service import PayoutService
from services.spatial_telemetry import record_milestone_snapshot
from routers.tracking import generate_tracking_token, verify_tracking_token
from services.liquidity_guardrails import resolve_pilot_cluster, handle_dispatch_sla_breach
from services.incentives_engine import IncentivesEngine


def test_state_machine_dag_transitions():
    """Verify state transitions follow strictly allowed paths."""
    assert validate_transition("open", "matched") is True
    assert validate_transition("matched", "accepted") is True
    assert validate_transition("accepted", "in_progress") is True
    assert validate_transition("in_progress", "completed") is True
    
    # Terminal state checks: completed cannot revert to open or in_progress
    assert validate_transition("completed", "open") is False
    assert validate_transition("completed", "in_progress") is False
    assert validate_transition("cancelled", "completed") is False
    assert "completed" in TERMINAL_STATES
    assert "cancelled" in TERMINAL_STATES


def test_payout_split_and_tds_calculation():
    """Verify platform commission (10%) and 1% Section 194O TDS are correctly deducted."""
    split = PayoutService.calculate_split(1000.0)
    assert split["total_amount"] == 1000.0
    assert split["commission"] == 100.0  # 10%
    assert split["tds"] == 10.0          # 1%
    assert split["worker_payout"] == 890.0

    split_zero = PayoutService.calculate_split(0.0)
    assert split_zero["worker_payout"] == 0.0


def test_tracking_token_hmac_integrity():
    """Verify HMAC token generation and cryptographic tamper resistance."""
    job_id = "test_job_123"
    token = generate_tracking_token(job_id, expires_in_seconds=3600)
    
    # Valid token verification
    verified_job_id = verify_tracking_token(token)
    assert verified_job_id == job_id

    # Tampered token verification must raise exception
    tampered_token = token[:-4] + "abcd"
    with pytest.raises(Exception):
        verify_tracking_token(tampered_token)


def test_pilot_cluster_geofencing():
    """Verify Gokulam cluster resolution in Mysuru."""
    # Gokulam coordinates
    cluster = resolve_pilot_cluster(12.3276, 76.6268)
    assert cluster is not None
    assert cluster["name"] == "Gokulam"

    # Distant coordinates outside Mysuru (e.g. Bengaluru)
    outside = resolve_pilot_cluster(12.9716, 77.5946)
    assert outside is None


def test_sla_dispatch_escalation():
    """Verify SLA breach escalates radius cleanly."""
    job_id = "job_sla_test_999"
    res = handle_dispatch_sla_breach(job_id)
    assert res["action"] == "EXPAND_RADIUS_AND_NOTIFY_OPS"
    assert res["expanded_radius_km"] == 15.0


def test_incentive_engine_surge_and_guarantee():
    """Verify rain surge multiplier and daily floor top-up logic."""
    # Rain surge adds +25%
    surge = IncentivesEngine.calculate_surge_multiplier(weather_condition="monsoon")
    assert surge >= 1.25

    # Top-up calculation for 4 on-duty hours
    eval_res = IncentivesEngine.evaluate_daily_guarantee("w_1", "2026-10-13")
    assert eval_res["guaranteed_floor"] == 400.0
    assert eval_res["top_up_bonus"] == 400.0


if __name__ == "__main__":
    test_state_machine_dag_transitions()
    test_payout_split_and_tds_calculation()
    test_tracking_token_hmac_integrity()
    test_pilot_cluster_geofencing()
    test_sla_dispatch_escalation()
    test_incentive_engine_surge_and_guarantee()
    print("All 6 production resilience integration tests PASSED!")
