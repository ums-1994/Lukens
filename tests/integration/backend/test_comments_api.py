import requests
import json

# Test getting comments for Template proposal
BASE_URL = "http://localhost:8000"

# First, login to get token
login_response = requests.post(
    f"{BASE_URL}/api/login",
    json={
        "username": "zukhanyeB",  # or whatever the creator's username is
        "password": "password123"
    }
)

if login_response.status_code == 200:
    token = login_response.json()['token']
    print(f"✅ Logged in, token: {token[:20]}...")
    
    # Get comments for proposal ID (need to find the ID first)
    # Try proposal IDs 1-10
    for proposal_id in range(1, 11):
        print(f"\n📋 Checking proposal {proposal_id}:")
        response = requests.get(
            f"{BASE_URL}/api/comments/proposal/{proposal_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        if response.status_code == 200:
            comments = response.json()
            print(f"  ✅ {len(comments)} comments found")
            for comment in comments:
                print(f"    - {comment.get('created_by_name', 'Unknown')}: {comment.get('comment_text', '')[:50]}")
        else:
            print(f"  ❌ Error: {response.status_code}")
else:
    print(f"❌ Login failed: {login_response.status_code} - {login_response.text}")

