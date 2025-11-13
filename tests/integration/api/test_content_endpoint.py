#!/usr/bin/env python3
import requests
import json

# Test the /content endpoint
url = "http://localhost:8000/content"

try:
    response = requests.get(url)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
except Exception as e:
    print(f"Error: {e}")
    print("Make sure the backend is running on port 8000")