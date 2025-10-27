#!/usr/bin/env python3
"""
Test script for the Approval Workflow Engine
Tests all the new endpoints and functionality
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_approval_workflow():
    print("Testing Approval Workflow Engine")
    print("=" * 50)
    
    # Test 1: Create a test approval workflow
    print("\n1. Creating test approval workflow...")
    workflow_data = {
        "name": "Test Workflow",
        "description": "Test workflow for approval testing",
        "stages": ["Delivery", "Legal", "Exec"],
        "mode": "sequential",
        "auto_assign": True,
        "escalation_enabled": True,
        "escalation_timeout_hours": 24,
        "created_by": "test_user",
        "is_active": True
    }
    
    try:
        response = requests.post(f"{BASE_URL}/approval-workflows", json=workflow_data)
        if response.status_code == 200:
            workflow = response.json()
            workflow_id = workflow["id"]
            print(f"[OK] Workflow created successfully: {workflow_id}")
        else:
            print(f"[ERROR] Failed to create workflow: {response.status_code}")
            print(response.text)
            return
    except Exception as e:
        print(f"[ERROR] Error creating workflow: {e}")
        return
    
    # Test 2: List workflows
    print("\n2. Listing approval workflows...")
    try:
        response = requests.get(f"{BASE_URL}/approval-workflows")
        if response.status_code == 200:
            workflows = response.json()
            print(f"[OK] Found {len(workflows)} workflows")
            for wf in workflows:
                print(f"   - {wf['name']} ({wf['id']})")
        else:
            print(f"[ERROR] Failed to list workflows: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Error listing workflows: {e}")
    
    # Test 3: Create a test proposal
    print("\n3. Creating test proposal...")
    proposal_data = {
        "title": "Test Proposal for Approval",
        "client": "Test Client",
        "dtype": "Proposal"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/proposals", json=proposal_data)
        if response.status_code == 200:
            proposal = response.json()
            proposal_id = proposal["id"]
            print(f"[OK] Proposal created successfully: {proposal_id}")
        else:
            print(f"[ERROR] Failed to create proposal: {response.status_code}")
            print(response.text)
            return
    except Exception as e:
        print(f"[ERROR] Error creating proposal: {e}")
        return
    
    # Test 4: Submit proposal for approval
    print("\n4. Submitting proposal for approval...")
    try:
        response = requests.post(f"{BASE_URL}/proposals/{proposal_id}/submit-for-approval", 
                               json={"workflow_id": workflow_id})
        if response.status_code == 200:
            result = response.json()
            print(f"[OK] Proposal submitted for approval successfully")
            print(f"   Workflow ID: {result['workflow_id']}")
            print(f"   Approval requests created: {len(result['approval_requests'])}")
        else:
            print(f"[ERROR] Failed to submit proposal: {response.status_code}")
            print(response.text)
            return
    except Exception as e:
        print(f"[ERROR] Error submitting proposal: {e}")
        return
    
    # Test 5: List approval requests
    print("\n5. Listing approval requests...")
    try:
        response = requests.get(f"{BASE_URL}/approval-requests")
        if response.status_code == 200:
            requests_list = response.json()
            print(f"[OK] Found {len(requests_list)} approval requests")
            for req in requests_list:
                print(f"   - {req['stage']} - {req['status']} (ID: {req['id']})")
        else:
            print(f"[ERROR] Failed to list approval requests: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Error listing approval requests: {e}")
    
    # Test 6: Get pending approvals for a user
    print("\n6. Getting pending approvals for admin user...")
    try:
        response = requests.get(f"{BASE_URL}/approval-requests/pending/admin")
        if response.status_code == 200:
            pending = response.json()
            print(f"[OK] Found {len(pending)} pending approvals for admin")
            for req in pending:
                print(f"   - {req['stage']} - Priority: {req['priority']}")
        else:
            print(f"[ERROR] Failed to get pending approvals: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Error getting pending approvals: {e}")
    
    # Test 7: Take approval action (if we have requests)
    print("\n7. Testing approval action...")
    try:
        response = requests.get(f"{BASE_URL}/approval-requests")
        if response.status_code == 200:
            requests_list = response.json()
            if requests_list:
                request_id = requests_list[0]["id"]
                action_data = {
                    "action": "approve",
                    "action_comments": "Test approval",
                    "action_taken_by": "test_user"
                }
                
                response = requests.post(f"{BASE_URL}/approval-requests/{request_id}/action", 
                                       json=action_data)
                if response.status_code == 200:
                    result = response.json()
                    print(f"[OK] Approval action taken successfully")
                    print(f"   Action: {result['request']['action_taken']}")
                else:
                    print(f"[ERROR] Failed to take approval action: {response.status_code}")
                    print(response.text)
            else:
                print("[WARNING] No approval requests found to test action")
        else:
            print(f"[ERROR] Failed to get requests for action test: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Error testing approval action: {e}")
    
    # Test 8: Get approval analytics
    print("\n8. Getting approval analytics...")
    try:
        response = requests.get(f"{BASE_URL}/approval-analytics")
        if response.status_code == 200:
            analytics = response.json()
            print(f"[OK] Analytics retrieved successfully:")
            print(f"   Total requests: {analytics['total_requests']}")
            print(f"   Pending: {analytics['pending_requests']}")
            print(f"   Approved: {analytics['approved_requests']}")
            print(f"   Rejected: {analytics['rejected_requests']}")
            print(f"   Approval rate: {analytics['approval_rate']:.2%}")
            print(f"   Avg time: {analytics['average_approval_time_hours']}h")
        else:
            print(f"[ERROR] Failed to get analytics: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Error getting analytics: {e}")
    
    # Test 9: Get proposal approval requests
    print("\n9. Getting proposal approval requests...")
    try:
        response = requests.get(f"{BASE_URL}/approval-requests/proposal/{proposal_id}")
        if response.status_code == 200:
            proposal_requests = response.json()
            print(f"[OK] Found {len(proposal_requests)} approval requests for proposal")
            for req in proposal_requests:
                print(f"   - {req['stage']} - {req['status']} - {req['action_taken'] or 'No action'}")
        else:
            print(f"[ERROR] Failed to get proposal approval requests: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Error getting proposal approval requests: {e}")
    
    print("\n" + "=" * 50)
    print("Approval Workflow Testing Complete!")
    print("Check the results above to verify all functionality is working.")

if __name__ == "__main__":
    test_approval_workflow()

    
