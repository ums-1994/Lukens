#!/usr/bin/env python3
"""
Debug autosave functionality
"""

import requests
import json
import uuid

def test_autosave():
    """Test autosave with detailed debugging"""
    
    # Get existing proposal
    response = requests.get('http://localhost:8000/proposals/d50a6cdb-1f10-424c-ae7f-408fb611315e')
    if response.status_code != 200:
        print(f"Failed to get proposal: {response.status_code}")
        return
    
    proposal = response.json()
    print("Current proposal sections:")
    print(json.dumps(proposal['sections'], indent=2))
    
    # Test sections for autosave
    new_sections = {
        'title': 'Test Proposal Debug 2',
        'description': 'Debug test 2',
        'test': 'auto-save-test-2025-09-29-14-10-50'
    }
    
    print("\nNew sections:")
    print(json.dumps(new_sections, indent=2))
    
    print(f"\nSections are equal: {proposal['sections'] == new_sections}")
    
    # Test autosave
    response = requests.post(
        'http://localhost:8000/proposals/d50a6cdb-1f10-424c-ae7f-408fb611315e/autosave',
        json={
            'sections': new_sections,
            'version': 'draft',
            'auto_saved': True,
            'timestamp': '2025-01-27T10:45:00Z',
            'user_id': 'test-user'
        }
    )
    
    print(f"\nAutosave response: {response.status_code}")
    print(f"Response: {response.text}")

if __name__ == "__main__":
    test_autosave()
