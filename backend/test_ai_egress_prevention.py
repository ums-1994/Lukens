import unittest
from unittest.mock import MagicMock, patch

import ai_service
from api.utils.ai_safety import AISafetyError, enforce_safe_for_external_ai


class TestAIEgressPrevention(unittest.TestCase):
    def setUp(self):
        ai_service.AI_PROVIDER = "openrouter"
        ai_service.OPENROUTER_API_KEY = "test-key"
        ai_service.OPENROUTER_BASE_URL = "https://example.invalid"
        ai_service.OPENROUTER_MODEL = "test/model"

    def test_openrouter_request_uses_sanitized_messages(self):
        service = ai_service.AIService()

        raw_messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Summarize: Hello world."},
        ]
        expected_messages = enforce_safe_for_external_ai(raw_messages)

        captured = {}

        def fake_post(url, headers=None, json=None, timeout=None):
            captured["url"] = url
            captured["json"] = json
            response = MagicMock()
            response.raise_for_status.return_value = None
            response.json.return_value = {
                "choices": [{"message": {"content": "ok"}}],
            }
            return response

        with patch.object(ai_service.requests, "post", side_effect=fake_post) as post_mock:
            result = service._make_request(raw_messages, temperature=0.3, max_tokens=100)

        self.assertEqual(result, "ok")
        self.assertEqual(post_mock.call_count, 1)
        self.assertIsInstance(captured.get("json"), dict)
        self.assertEqual(captured["json"].get("messages"), expected_messages)

    def test_openrouter_blocks_egress_when_pii_detected(self):
        service = ai_service.AIService()

        raw_messages = [
            {"role": "user", "content": "Email me at john.doe@example.com"},
        ]

        with patch.object(ai_service.requests, "post") as post_mock:
            with self.assertRaises(AISafetyError):
                service._make_request(raw_messages)

        self.assertEqual(post_mock.call_count, 0)


if __name__ == "__main__":
    unittest.main()
