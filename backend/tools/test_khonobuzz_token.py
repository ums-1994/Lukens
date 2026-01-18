"""
Quick tester for KHONOBUZZ token handling against local backend.

- Tests local decode using api.utils.jwt_validator.validate_jwt_token
- Tests HTTP POST to /api/khonobuzz/jwt-login

Usage:
  1) Ensure backend is running:  python app.py
  2) Run this tester:          python tools/test_khonobuzz_token.py
"""
import json
import os
import sys
from typing import Optional

import requests
from dotenv import load_dotenv

# Provided test token (Fernet-encrypted)
TEST_TOKEN = (
    "gAAAAABpbJUVzi5i48UxVLE482MF2g3Y9h5h7liF4jrJsx2ml1yVrKfM7k-zASENOoFJxcw-gzPoiTVRvjEyopKTkTz3MyK8DwtApx7qDNHBOFZM--y0mB0u9pCzzzF94BwMgmb8_fSTCbYsXNxCAOIT4dE7in0jni82tunuWulyRQakXfAz5GQpS5mw5R7v5TTEDQCkID7RGFnXHhoj0hbOqvOFXc3l3DOWMv06zwl1m97r8gpt8iUp5cCZ5krTNRqqkl6gIDzF_9FSeqSzUpAoKG5O8I_-j6sb4eUsX-zLB07Kihb05-rgUU2mFAIp6R_ESw4rJpveqlt2XlnBNwGPCc1fWa_hJPQiwgrr3HeU5EMqx2Be7PAq16opJdQNG2Diun9dx7gGcnrK4rUS2r_KN0Z62_lUDOvFFWK03ZoW12Q3s-1pqUkXUGdX4ixbs8M5WhmvJ32JwkzyOMehwhNc68skp6C9MchMXeZ01fsVmVX2WWdRMJW0QzhpRUBrTjSMO8YuQpZJtq4-jmxV88rfvSl6VJ1UDZ4njlujkoty6lCDC9VpISxEs36hc0dUY_jCTJ3WlJlAvLVFcsIfCFbeKzw8h0N5O9PBJe4qfPF0jyjR112buHXXgIjrYz_cNnwGouV6qpFZorrX7lC6iqp6rXKF5ybn9INpHTjlt-rd_2ZZPP8w2-C1UOSQwpaTuqP5XzSeV2leJm5RXyQ5NTROPUkVWGlRvXSGjRtQlxiExGFdLhU1bE2Zv9ciQb1yxz61qR6GsmsM"
)


def _print_env():
    keys = [
        "ENCRYPTION_KEY",
        "JWT_ENCRYPTION_KEY",
        "FERNET_KEY",
        "JWT_SECRET",
        "JWT_SECRET_KEY",
        "SECRET_KEY",
    ]
    print("\n[ENV] Relevant keys (showing lengths only):")
    for k in keys:
        v = os.getenv(k)
        if v:
            print(f"  {k}: len={len(v)}")
        else:
            print(f"  {k}: <not set>")


def test_local_decode(token: str) -> Optional[dict]:
    print("\n[TEST] Local decode via validate_jwt_token()")
    try:
        from api.utils.jwt_validator import validate_jwt_token
        claims = validate_jwt_token(token)
        print("  ✅ Decoded claims:")
        print(json.dumps(claims, indent=2))
        return claims
    except Exception as e:
        print(f"  ❌ Local decode failed: {e}")
        return None


def test_http_endpoint(base_url: str, token: str) -> Optional[dict]:
    print("\n[TEST] HTTP POST /api/khonobuzz/jwt-login")
    url = f"{base_url.rstrip('/')}/api/khonobuzz/jwt-login"
    try:
        r = requests.post(url, json={"token": token}, timeout=10)
        print(f"  Status: {r.status_code}")
        ctype = r.headers.get("Content-Type", "")
        if "application/json" in ctype:
            data = r.json()
            print("  ✅ Response JSON:")
            print(json.dumps(data, indent=2))
            return data
        else:
            print("  ❌ Non-JSON response:")
            print(r.text[:500])
            return None
    except Exception as e:
        print(f"  ❌ HTTP test failed: {e}")
        return None


def main():
    load_dotenv()
    _print_env()

    base_url = os.getenv("BACKEND_URL", "http://localhost:8000")

    # 1) Try local decode
    _ = test_local_decode(TEST_TOKEN)

    # 2) Test HTTP endpoint
    _ = test_http_endpoint(base_url, TEST_TOKEN)


if __name__ == "__main__":
    sys.exit(main())
