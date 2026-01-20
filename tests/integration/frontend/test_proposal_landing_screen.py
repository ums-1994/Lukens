#!/usr/bin/env python3
"""
Test script to verify Proposal_Landing_Screen token handling and role routing
Tests different user roles to ensure proper navigation
"""

import requests
import json
import time
from typing import Dict, Any

# Backend URL
BACKEND_URL = "http://localhost:8000"

# Test tokens for different roles (these should be valid tokens from your system)
TEST_TOKENS = {
    "finance": "gAAAAABpbxCyUMyw7P-d3t4ZqkMFg1p-bN2R7gc1ebXrWaOv4rW8M8t8wMQRkftLum-XFRJjt6FNrijzksfb7x-Gsos42ecodXNxSHOnoch244Z7g58ogkar5Og7VE26inFAM3m1YOzlwComYI6LRUDnWE6aIM_dQmONdPIQ5WHD9RO43G0DL_l39lbX4BdT7roLhfdD7FFZZ6poHkIJQ7SNHrwthBE0Ljo0wkXq7oKMgo0ADlGHFudfoaszO1NeawV_5UOhNrfYxasmtiFYZZS80fYDSWvRWUE58lyQ0178GQhvapnmni7Kg3cBIRr6q4SRNerY3CuJdwLGv4zrMrHXLYGM3EQjP082hrvbDn_CfhH_3M4RLKHw_qQNUffEu1JTfDx-JgtgIbfkMjoDHreDCyu9DdRzq3B-a4yjTyvzS21ZzfvRZvBiX6XPjp33LZ1OjgCvSBFSArSoAPHVDezu7_MRaNd6Ro-962t47PHeh3n-PUeGWqqYD-QKF1FUid6_21QnsAjyYTl5yx32aS5w3ycCLJPNypCmWjyxDDCQAHqZ-XJkLFSZBFm-BZ6HmzyED9eEGe8l4k0yjUuXOv26rIyURCu99M383ctJ-UsZVLre7quDbwGL-UhCjF2qO2VuqJiobmd3JKkJv0AmVgvfFrLBxxxfOOsfENNj31thkfTMcOQ9eSWBQBegQZGZa6BcshTrbhQ-I_mrImFPX58yDwqYdK-wRu7MrxHVvaFAFdOGnYrHY3M%3D",
    # Add more test tokens for other roles as needed
}

def test_jwt_endpoint(token: str, role_name: str) -> Dict[str, Any]:
    """Test JWT token with backend endpoint"""
    print(f"\n{'='*60}")
    print(f"Testing {role_name} role token")
    print(f"{'='*60}")
    
    try:
        response = requests.post(
            f"{BACKEND_URL}/api/khonobuzz/jwt-login",
            json={"token": token},
            timeout=15
        )
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            user = data.get('user', {})
            claims = data.get('claims', {})
            
            print(f"✅ Authentication successful!")
            print(f"📧 Email: {user.get('email', 'N/A')}")
            print(f"👤 Name: {user.get('full_name', 'N/A')}")
            print(f"🔑 Role: {user.get('role', 'N/A')}")
            print(f"🏢 Department: {user.get('department', 'N/A')}")
            print(f"🎭 Roles from claims: {claims.get('roles', [])}")
            
            # Determine expected dashboard route based on role
            role = user.get('role', '').lower().strip()
            expected_route = determine_dashboard_route(role)
            print(f"🧭 Expected dashboard route: {expected_route}")
            
            return {
                "success": True,
                "user": user,
                "claims": claims,
                "expected_route": expected_route,
                "role": role
            }
        else:
            print(f"❌ Authentication failed")
            print(f"Response: {response.text}")
            return {"success": False, "error": response.text}
            
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return {"success": False, "error": str(e)}

def determine_dashboard_route(role: str) -> str:
    """Determine dashboard route based on user role (matches Flutter logic)"""
    role = role.lower().strip()
    
    # Admin roles → Approver Dashboard
    if role in ['admin', 'ceo']:
        return '/approver_dashboard'
    
    # Finance roles → Finance Dashboard
    if role in ['finance', 'finance manager', 'financial manager', 'proposal & sow builder - finance']:
        return '/finance_dashboard'
    
    # Manager roles → Creator Dashboard
    if role in ['manager', 'creator', 'user']:
        return '/creator_dashboard'
    
    # Default to creator dashboard
    return '/creator_dashboard'

def test_url_token_extraction():
    """Test URL token extraction patterns that Flutter code uses"""
    print(f"\n{'='*60}")
    print("Testing URL Token Extraction Patterns")
    print(f"{'='*60}")
    
    test_urls = [
        "https://example.com/?token=test_token_123",
        "https://example.com/?jwt=test_jwt_456", 
        "https://example.com/?access_token=test_access_789",
        "https://example.com/?id_token=test_id_012",
        "https://example.com/#token=test_hash_token",
        "https://example.com/#jwt=test_hash_jwt",
    ]
    
    import re
    from urllib.parse import urlparse, parse_qs
    
    for url in test_urls:
        print(f"\nTesting URL: {url}")
        
        # Parse URL
        uri = urlparse(url)
        
        # Check query parameters (matches Flutter logic)
        query_token = (
            parse_qs(uri.query).get('token', [None])[0] or
            parse_qs(uri.query).get('jwt', [None])[0] or
            parse_qs(uri.query).get('access_token', [None])[0] or
            parse_qs(uri.query).get('id_token', [None])[0]
        )
        
        # Check hash fragment (matches Flutter logic)
        hash_token = None
        if query_token is None:
            hash_match = re.search(r'(?:token|jwt|access_token|id_token)=([^&#]+)', url)
            if hash_match:
                hash_token = hash_match.group(1)
        
        extracted_token = query_token or hash_token
        print(f"  ✅ Extracted token: {extracted_token}")

def simulate_flutter_routing_logic(user_data: Dict[str, Any]) -> str:
    """Simulate the exact routing logic from Proposal_Landing_Screen"""
    raw_role = user_data.get('role', '').toString() if hasattr(user_data.get('role', ''), 'toString') else str(user_data.get('role', ''))
    user_role = raw_role.lower().strip()
    
    # Exact logic from Flutter code
    is_admin = user_role == 'admin' or user_role == 'ceo'
    is_finance = (user_role == 'proposal & sow builder - finance' or
                  user_role == 'finance' or
                  user_role == 'financial manager')
    is_manager = (user_role == 'manager' or
                  user_role == 'creator' or
                  user_role == 'user')
    
    if is_admin:
        return '/approver_dashboard'
    elif is_finance:
        return '/finance_dashboard'
    elif is_manager:
        return '/creator_dashboard'
    else:
        return '/creator_dashboard'

def main():
    print("🧪 Proposal Landing Screen Token & Role Testing")
    print("=" * 60)
    
    # Test 1: URL token extraction patterns
    test_url_token_extraction()
    
    # Test 2: JWT token validation for different roles
    print(f"\n{'='*60}")
    print("JWT Token Validation Tests")
    print(f"{'='*60}")
    
    results = {}
    
    for role_name, token in TEST_TOKENS.items():
        result = test_jwt_endpoint(token, role_name)
        results[role_name] = result
        
        if result["success"]:
            # Test routing logic
            expected_route = simulate_flutter_routing_logic(result["user"])
            if expected_route == result["expected_route"]:
                print(f"✅ Routing logic matches: {expected_route}")
            else:
                print(f"❌ Routing mismatch: Expected {result['expected_route']}, Got {expected_route}")
        
        # Small delay between requests
        time.sleep(1)
    
    # Summary
    print(f"\n{'='*60}")
    print("TEST SUMMARY")
    print(f"{'='*60}")
    
    for role_name, result in results.items():
        status = "✅ PASS" if result["success"] else "❌ FAIL"
        print(f"{role_name}: {status}")
        if result["success"]:
            print(f"  Route: {result['expected_route']}")
    
    print(f"\n🎯 Proposal_Landing_Screen should handle these scenarios:")
    print("  1. Extract tokens from URL query parameters")
    print("  2. Extract tokens from URL hash fragments") 
    print("  3. Validate tokens with backend JWT endpoint")
    print("  4. Parse user roles and route to correct dashboard")
    print("  5. Handle authentication errors gracefully")

if __name__ == "__main__":
    main()
