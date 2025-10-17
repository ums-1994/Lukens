#!/usr/bin/env python3
"""
Test script to verify the refactored client dashboard functionality
"""

import requests
import json
import jwt
import time

# Configuration
BASE_URL = "http://localhost:8000"
SECRET_KEY = "your-secret-key-change-in-production"  # Should match the app's secret key
ALGORITHM = "HS256"

def create_test_token():
    """Create a test JWT token for client dashboard access"""
    payload = {
        "client_email": "test.client@example.com",
        "proposal_id": "test-proposal-123",
        "proposal_data": {
            "title": "Test Business Proposal",
            "client": "Test Client Inc.",
            "status": "Released"
        },
        "exp": int(time.time()) + 3600  # Expires in 1 hour
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token

def test_client_dashboard():
    """Test the client dashboard functionality"""
    print("🧪 Testing Client Dashboard Refactoring...")
    
    try:
        # Create test token
        token = create_test_token()
        print(f"✅ Test token created: {token[:50]}...")
        
        # Test BOTH dashboard endpoints
        print("\n📱 Testing Mini Dashboard (HTML):")
        mini_dashboard_url = f"{BASE_URL}/client-dashboard-mini/{token}"
        print(f"🌐 Mini dashboard URL: {mini_dashboard_url}")
        
        response = requests.get(mini_dashboard_url)
        print(f"📊 Mini dashboard response status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Mini client dashboard loaded successfully!")
            
            # Check if the HTML contains expected elements
            html_content = response.text
            expected_elements = [
                "Client Dashboard",
                "Welcome to Your Client Portal",
                "My Proposals",
                "Sign Documents",
                "Signed History",
                "Feedback"
            ]
            
            for element in expected_elements:
                if element in html_content:
                    print(f"✅ Found expected element: {element}")
                else:
                    print(f"❌ Missing expected element: {element}")
        else:
            print(f"❌ Mini client dashboard failed: {response.text}")

        # Test Flutter Client Portal URL (this is what you should use!)
        print("\n🚀 Flutter Client Portal URL:")
        flutter_portal_url = f"http://localhost:8080/#/client_portal?token={token}"
        print(f"🌐 Flutter portal URL: {flutter_portal_url}")
        print("👆 *** USE THIS URL TO ACCESS THE FULL CLIENT PORTAL! ***")
        
        # Test token validation endpoint
        print("\n🔐 Testing Token Validation:")
        validation_response = requests.get(
            f"{BASE_URL}/client/validate-token",
            headers={'Authorization': f'Bearer {token}'}
        )
        print(f"🔑 Token validation status: {validation_response.status_code}")
        
        if validation_response.status_code == 200:
            validation_data = validation_response.json()
            print(f"✅ Token validation successful: {validation_data}")
        else:
            print(f"❌ Token validation failed: {validation_response.text}")
            
        # Test dashboard stats endpoint
        stats_response = requests.get(f"{BASE_URL}/client/dashboard_stats")
        print(f"📈 Stats response status: {stats_response.status_code}")
        
        if stats_response.status_code == 200:
            stats = stats_response.json()
            print(f"✅ Dashboard stats loaded: {stats}")
        else:
            print(f"❌ Failed to load dashboard stats: {stats_response.text}")
                
    except requests.exceptions.ConnectionError:
        print("❌ Flask backend is not running. Please start it with: cd backend && python app.py")
    except Exception as e:
        print(f"❌ Error testing client dashboard: {e}")

def test_client_proposals_api():
    """Test the client proposals API endpoints"""
    print("\n🔍 Testing Client Proposals API...")
    
    try:
        # Test client proposals endpoint
        response = requests.get(f"{BASE_URL}/client/proposals")
        print(f"📋 Client proposals status: {response.status_code}")
        
        if response.status_code == 200:
            proposals = response.json()
            print(f"✅ Found {len(proposals)} proposals")
            for proposal in proposals[:3]:  # Show first 3
                print(f"  - {proposal.get('title', 'Untitled')} ({proposal.get('status', 'Unknown')})")
        else:
            print(f"❌ Failed to load proposals: {response.text}")
            
    except Exception as e:
        print(f"❌ Error testing proposals API: {e}")

if __name__ == "__main__":
    print("🚀 Starting Client Dashboard Tests...")
    test_client_dashboard()
    test_client_proposals_api()
    print("\n✨ Test completed!")
