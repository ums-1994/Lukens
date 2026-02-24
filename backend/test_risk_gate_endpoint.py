#!/usr/bin/env python3
"""
Smoke test for POST /api/risk-gate/analyze
Requires a valid proposal_id in the DB.
"""
import os
import json
import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:8000")
DEV_BYPASS_AUTH = os.getenv("DEV_BYPASS_AUTH", "false").lower() in ("1", "true", "yes")

def main():
    # Try the new clean proposal (no PII)
    for proposal_id in [98]:
        headers = {"Content-Type": "application/json"}
        if DEV_BYPASS_AUTH:
            headers["X-Dev-Bypass-User"] = "admin"

        payload = {"proposal_id": proposal_id}

        print(f"\n📡 POST {BASE_URL}/api/risk-gate/analyze")
        print(f"📄 Payload: {json.dumps(payload, indent=2)}")
        print(f"🔐 Auth bypass: {DEV_BYPASS_AUTH}")

        try:
            resp = requests.post(f"{BASE_URL}/api/risk-gate/analyze", json=payload, headers=headers, timeout=30)
            print(f"🔢 Status: {resp.status_code}")
            try:
                print(f"📦 Response:\n{json.dumps(resp.json(), indent=2)}")
            except Exception:
                print(f"📦 Raw response:\n{resp.text}")
            if resp.status_code == 200:
                break
        except Exception as e:
            print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    main()
