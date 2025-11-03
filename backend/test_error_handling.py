#!/usr/bin/env python3
"""
Test script to verify the enhanced error handling system
"""

import requests
import json

BASE_URL = "http://localhost:8000"

def test_validation_error():
    """Test validation error with invalid email"""
    print("🧪 Testing validation error (invalid email)...")
    
    response = requests.post(
        f"{BASE_URL}/register",
        json={
            "email": "invalid-email",
            "password": "123",
            "username": "testuser"
        }
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print("-" * 50)

def test_missing_fields():
    """Test validation error with missing fields"""
    print("🧪 Testing missing required fields...")
    
    response = requests.post(
        f"{BASE_URL}/register",
        json={
            "email": "test@example.com"
            # Missing username and password
        }
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print("-" * 50)

def test_authentication_error():
    """Test authentication error with invalid credentials"""
    print("🧪 Testing authentication error (invalid credentials)...")
    
    response = requests.post(
        f"{BASE_URL}/login-email",
        json={
            "email": "nonexistent@example.com",
            "password": "wrongpassword"
        }
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print("-" * 50)

def test_health_check():
    """Test health check endpoint"""
    print("🧪 Testing health check endpoint...")
    
    response = requests.get(f"{BASE_URL}/health")
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print("-" * 50)

if __name__ == "__main__":
    print("🚀 Testing Enhanced Error Handling System")
    print("=" * 50)
    
    try:
        # Test health check first
        test_health_check()
        
        # Test various error scenarios
        test_missing_fields()
        test_validation_error()
        test_authentication_error()
        
        print("✅ All tests completed!")
        
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to Flask server. Make sure it's running on localhost:8000")
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
