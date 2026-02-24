#!/usr/bin/env python3
"""Smoke test for POST /api/risk-gate/override

Usage:
  - Ensure backend is running (local or deployed)
  - Set APP_BASE_URL (default http://localhost:8000)
  - Set DEV_BYPASS_AUTH=true to use X-Dev-Bypass-User header

This script:
  1) Calls /api/risk-gate/analyze to create a run and capture run_id
  2) Calls /api/risk-gate/override as unauthorized user (expect 403)
  3) Calls /api/risk-gate/override as authorized user (expect 200)
"""

import json
import os
import sys
import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:8000").rstrip("/")
DEV_BYPASS_AUTH = os.getenv("DEV_BYPASS_AUTH", "false").lower() in ("1", "true", "yes")


def _headers(user: str | None = None):
    headers = {"Content-Type": "application/json"}
    if DEV_BYPASS_AUTH and user:
        headers["X-Dev-Bypass-User"] = user
    return headers


def _pretty(resp: requests.Response):
    try:
        return json.dumps(resp.json(), indent=2)
    except Exception:
        return resp.text


def main():
    proposal_id = int(os.getenv("RISK_GATE_TEST_PROPOSAL_ID", "98"))
    authorized_user = os.getenv("RISK_GATE_OVERRIDE_AUTH_USER", "admin")

    print(f"\n1) POST {BASE_URL}/api/risk-gate/analyze (proposal_id={proposal_id})")
    resp = requests.post(
        f"{BASE_URL}/api/risk-gate/analyze",
        json={"proposal_id": proposal_id},
        headers=_headers("manager"),
        timeout=60,
    )
    print("Status:", resp.status_code)
    print(_pretty(resp))

    if resp.status_code not in (200, 400):
        print("Unexpected analyze status; cannot continue.")
        sys.exit(1)

    body = resp.json()
    run_id = body.get("run_id")
    if not run_id:
        print("No run_id in response; cannot continue.")
        sys.exit(1)

    print(f"\n2) POST {BASE_URL}/api/risk-gate/override as unauthorized (expect 403)")
    resp2 = requests.post(
        f"{BASE_URL}/api/risk-gate/override",
        json={"run_id": run_id, "override_reason": "Test override - unauthorized"},
        headers=_headers("user"),
        timeout=30,
    )
    print("Status:", resp2.status_code)
    print(_pretty(resp2))

    print(f"\n3) POST {BASE_URL}/api/risk-gate/override as authorized (expect 200)")
    resp3 = requests.post(
        f"{BASE_URL}/api/risk-gate/override",
        json={"run_id": run_id, "override_reason": "Test override - authorized"},
        headers=_headers(authorized_user),
        timeout=30,
    )
    print("Status:", resp3.status_code)
    print(_pretty(resp3))


if __name__ == "__main__":
    main()
