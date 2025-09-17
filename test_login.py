#!/usr/bin/env python3
"""
Test script to verify login functionality
"""

import requests
import json

# Test login with the existing user
def test_login():
    url = "http://localhost:8000/login"
    
    # Test with username (not email)
    data = {
        "username": "Unathi",
        "password": "test123"  # Try a common test password
    }
    
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    
    try:
        response = requests.post(url, data=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("✅ Login successful!")
            result = response.json()
            print(f"Access Token: {result.get('access_token', 'N/A')[:50]}...")
        else:
            print("❌ Login failed")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_login()

