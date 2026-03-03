import datetime

import requests


def _headers(device_id: str, session_token: str | None = None):
    headers = {
        "X-Client-Device-Id": device_id,
    }
    if session_token:
        headers["X-Client-Session-Token"] = session_token
    return headers


def test_identity_gating_then_unlock(api_base_url, seeded_client_invitation):
    token = seeded_client_invitation["access_token"]
    last4 = seeded_client_invitation["last4"]

    device_id = "pytest-device-1"

    r = requests.get(
        f"{api_base_url}/api/client/proposals",
        params={"token": token},
        headers=_headers(device_id),
        timeout=20,
    )
    assert r.status_code == 428
    body = r.json()
    assert body.get("identity_required") is True

    v = requests.post(
        f"{api_base_url}/api/client/verify-identity",
        json={"token": token, "last4": last4, "device_id": device_id},
        headers=_headers(device_id),
        timeout=20,
    )
    assert v.status_code == 200
    vbody = v.json()
    assert vbody.get("unlocked_token")
    assert vbody.get("session_token")

    unlocked_token = vbody["unlocked_token"]
    session_token = vbody["session_token"]

    ok = requests.get(
        f"{api_base_url}/api/client/proposals",
        params={"token": unlocked_token},
        headers=_headers(device_id, session_token),
        timeout=20,
    )
    assert ok.status_code == 200
    ok_body = ok.json()
    assert "proposals" in ok_body


def test_session_expiry_forces_reverify(api_base_url, seeded_client_invitation, db_conn):
    token = seeded_client_invitation["access_token"]
    last4 = seeded_client_invitation["last4"]

    device_id = "pytest-device-expire"

    v = requests.post(
        f"{api_base_url}/api/client/verify-identity",
        json={"token": token, "last4": last4, "device_id": device_id},
        headers=_headers(device_id),
        timeout=20,
    )
    assert v.status_code == 200
    vbody = v.json()
    unlocked_token = vbody["unlocked_token"]
    session_token = vbody["session_token"]

    with db_conn() as conn:
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE client_device_sessions
            SET expires_at = %s
            WHERE invitation_token = %s AND device_id = %s
            """,
            (datetime.datetime(2000, 1, 1), token, device_id),
        )

    r = requests.get(
        f"{api_base_url}/api/client/proposals",
        params={"token": unlocked_token},
        headers=_headers(device_id, session_token),
        timeout=20,
    )
    assert r.status_code == 428
    body = r.json()
    assert body.get("requires_identity_verification") is True


def test_trusted_device_start_session_without_otp(api_base_url, seeded_client_invitation):
    token = seeded_client_invitation["access_token"]
    last4 = seeded_client_invitation["last4"]

    device_id = "pytest-device-trusted"

    v = requests.post(
        f"{api_base_url}/api/client/verify-identity",
        json={"token": token, "last4": last4, "device_id": device_id},
        headers=_headers(device_id),
        timeout=20,
    )
    assert v.status_code == 200
    unlocked_token = v.json()["unlocked_token"]

    s = requests.post(
        f"{api_base_url}/api/client/device-session/start",
        json={"token": unlocked_token, "device_id": device_id},
        headers=_headers(device_id),
        timeout=20,
    )
    assert s.status_code == 200
    sbody = s.json()
    assert sbody.get("otp_required") is False
    assert sbody.get("session_token")
