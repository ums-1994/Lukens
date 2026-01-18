#!/usr/bin/env python3
"""
Test script to check if environment variables are loaded correctly in production
"""
import requests
import json

def test_env_vars():
    """Test if environment variables are properly configured"""
    backend_url = "https://backend-sow.onrender.com"
    
    # Test the basic auth endpoint to see if it's working
    print("=== Testing basic auth endpoint ===")
    try:
        response = requests.get(f"{backend_url}/api/test", timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")
    
    # Test a simple endpoint that might show environment info
    print("\n=== Testing environment debug endpoint ===")
    try:
        # Try to access an endpoint that might show environment info
        response = requests.get(f"{backend_url}/api/khonobuzz/jwt-login", timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_env_vars()
