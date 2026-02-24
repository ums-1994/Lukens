import os
import unittest
from unittest.mock import patch

from flask import Flask


class TestAISafetyEndpoints(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["DEV_BYPASS_AUTH"] = "true"
        os.environ["DEV_DEFAULT_USERNAME"] = "admin"

        from api.routes.creator import bp as creator_bp

        app = Flask(__name__)
        app.testing = True
        app.register_blueprint(creator_bp, url_prefix="/api")
        cls.app = app

    def test_ai_improve_blocks_pii_and_does_not_leak(self):
        client = self.app.test_client()

        payload = {
            "content": "Client email is john.doe@example.com and phone is +1 (415) 555-2671. API key sk-live-1234567890abcdef.",
            "section_type": "executive_summary",
        }

        resp = client.post("/api/ai/improve", json=payload)
        self.assertEqual(resp.status_code, 400)

        data = resp.get_json() or {}
        self.assertTrue(data.get("blocked"))

        reasons = data.get("reasons") or []
        self.assertIn("email", reasons)
        self.assertIn("phone", reasons)
        self.assertIn("openai_api_key", reasons)

        raw = resp.get_data(as_text=True) or ""
        self.assertNotIn("john.doe@example.com", raw)
        self.assertNotIn("415", raw)
        self.assertNotIn("sk-live-1234567890abcdef", raw)

    def test_ai_improve_clean_returns_200_with_mocked_ai(self):
        client = self.app.test_client()

        payload = {
            "content": "Please improve this executive summary for clarity and conciseness.",
            "section_type": "executive_summary",
        }

        fake_result = {
            "quality_score": 80,
            "strengths": ["Clear structure"],
            "improvements": [],
            "improved_version": "Improved text",
            "summary": "Updated for clarity",
        }

        with patch("ai_service.ai_service.improve_content", return_value=fake_result), patch(
            "api.routes.creator.get_db_connection", side_effect=Exception("db disabled")
        ):
            resp = client.post("/api/ai/improve", json=payload)

        self.assertEqual(resp.status_code, 200)
        data = resp.get_json() or {}
        self.assertEqual(data.get("improved_version"), "Improved text")


if __name__ == "__main__":
    unittest.main()
