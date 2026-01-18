#!/usr/bin/env python3
"""
Debug script to test JWT login endpoint and show what's happening
"""
import requests
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Test token (Fernet-encrypted)
TEST_TOKEN = "gAAAAABpbJUVzi5i48UxVLE482MF2g3Y9h5h7liF4jrJsx2ml1yVrKfM7k-zASENOoFJxcw-gzPoiTVRvjEyopKTkTz3MyK8DwtApx7qDNHBOFZM--y0mB0u9pCzzzF94BwMgmb8_fSTCbYsXNxCAOIT4dE7in0jni82tunuWulyRQakXfAz5GQpS5mw5R7v5TTEDQCkID7RGFnXHhoj0hbOqvOFXc3l3DOWMv06zwl1m97r8gpt8iUp5cCZ5krTNRqqkl6gIDzF_9FSeqSzUpAoKG5O8I_-j6sb4eUsX-zLB07Kihb05-rgUU2mFAIp6R_ESw4rJpveqlt2XlnBNwGPCc1fWa_hJPQiwgrr3HeU5EMqx2Be7PAq16opJdQNG2Diun9dx7gGcnrK4rUS2r_KN0Z62_lUDOvFFWK03ZoW12Q3s-1pqUkXUGdX4ixbs8M5WhmvJ32JwkzyOMehwhNc68skp6C9MchMXeZ01fsVmVX2WWdRMJW0QzhpRUBrTjSMO8YuQpZJtq4-jmxV88rfvSl6VJ1UDZ4njlujkoty6lCDC9VpISxEs36hc0dUY_jCTJ3WlJlAvLVFcsIfCFbeKzw8h0N5O9PBJe4qfPF0jyjR112buHXXgIjrYz_cNnwGouV6qpFZorrX7lC6iqp6rXKF5ybn9INpHTjlt-rd_2ZZPP8w2-C1UOSQwpaTuqP5XzSeV2leJm5RXyQ5NTROPUkVWGlRvXSGjRtQlxiExGFdLhU1bE2Zv9ciQb1yxz61qR6GsmsM"

def test_endpoint():
    """Test the JWT login endpoint with debugging"""
    backend_url = "https://backend-sow.onrender.com"
    endpoint = f"{backend_url}/api/khonobuzz/jwt-login"
    
    print(f"Testing endpoint: {endpoint}")
    print(f"Token length: {len(TEST_TOKEN)}")
    print(f"Token preview: {TEST_TOKEN[:50]}...")
    
    # Test with JSON payload
    print("\n=== Testing JSON payload ===")
    try:
        response = requests.post(
            endpoint,
            json={"token": TEST_TOKEN},
            headers={"Content-Type": "application/json"},
            timeout=15
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Response Body: {response.text}")
        
        if response.headers.get('Content-Type', '').startswith('application/json'):
            try:
                data = response.json()
                print(f"Parsed JSON: {json.dumps(data, indent=2)}")
            except:
                print("Failed to parse JSON response")
        
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
    
    # Test with query parameter
    print("\n=== Testing query parameter ===")
    try:
        response = requests.post(
            f"{endpoint}?token={TEST_TOKEN}",
            headers={"Content-Type": "application/json"},
            timeout=15
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Body: {response.text}")
        
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_endpoint()
