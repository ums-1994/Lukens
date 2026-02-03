import unittest

from api.utils.ai_safety import AISafetyError, enforce_safe_for_external_ai, sanitize_for_external_ai


class TestAISafety(unittest.TestCase):
    def test_redacts_email_and_phone(self):
        payload = {
            "contact": "Reach me at john.doe@example.com or +1 (555) 123-4567",
            "notes": "No secrets here",
        }
        result = sanitize_for_external_ai(payload)
        self.assertTrue(result.blocked)
        self.assertIn("[REDACTED_EMAIL]", result.sanitized["contact"])
        self.assertIn("[REDACTED_PHONE]", result.sanitized["contact"])
        self.assertIn("email", result.redactions)
        self.assertIn("phone", result.redactions)
        self.assertIn("email", result.block_reasons)
        self.assertIn("phone", result.block_reasons)

        with self.assertRaises(AISafetyError) as ctx:
            enforce_safe_for_external_ai(payload)
        self.assertIn("email", ctx.exception.reasons)
        self.assertIn("phone", ctx.exception.reasons)

    def test_redacts_nested_payload(self):
        payload = {
            "level1": {
                "list": [
                    {"text": "Contact: jane.doe@example.com"},
                    "Call me on +1 (415) 555-2671",
                ]
            }
        }

        result = sanitize_for_external_ai(payload)
        self.assertTrue(result.blocked)
        self.assertIn("[REDACTED_EMAIL]", result.sanitized["level1"]["list"][0]["text"])
        self.assertIn("[REDACTED_PHONE]", result.sanitized["level1"]["list"][1])
        self.assertIn("email", result.redactions)
        self.assertIn("phone", result.redactions)

    def test_blocks_private_key(self):
        payload = {
            "text": "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----",
        }
        result = sanitize_for_external_ai(payload)
        self.assertTrue(result.blocked)
        self.assertIn("private_key", result.block_reasons)

        with self.assertRaises(AISafetyError):
            enforce_safe_for_external_ai(payload)

    def test_blocks_bearer_token(self):
        payload = "Authorization: Bearer abc.def.ghi"
        result = sanitize_for_external_ai(payload)
        self.assertTrue(result.blocked)
        self.assertIn("bearer_token", result.block_reasons)

        with self.assertRaises(AISafetyError) as ctx:
            enforce_safe_for_external_ai(payload)
        self.assertIn("bearer_token", ctx.exception.reasons)

    def test_blocks_openai_api_key_variants(self):
        payload = {
            "text": "Use sk-live-1234567890abcdef for auth and sk-test-abcdef1234567890 for staging.",
        }
        result = sanitize_for_external_ai(payload)
        self.assertTrue(result.blocked)
        self.assertIn("openai_api_key", result.block_reasons)
        self.assertIn("[REDACTED_API_KEY]", result.sanitized["text"])

        with self.assertRaises(AISafetyError) as ctx:
            enforce_safe_for_external_ai(payload)
        self.assertIn("openai_api_key", ctx.exception.reasons)

    def test_blocks_google_api_key(self):
        payload = "AIzaSyAwYO3fPvjHeRT5DEg1rhLm5SYOzP_wwUo"
        result = sanitize_for_external_ai(payload)
        self.assertTrue(result.blocked)
        self.assertIn("google_api_key", result.block_reasons)

        with self.assertRaises(AISafetyError) as ctx:
            enforce_safe_for_external_ai(payload)
        self.assertIn("google_api_key", ctx.exception.reasons)


if __name__ == "__main__":
    unittest.main()
