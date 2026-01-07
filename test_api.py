import requests
import json

# Login as finance user
login_data = {
    'username': 'finance_user',
    'password': 'password123'
}

try:
    response = requests.post('http://127.0.0.1:8000/api/auth/login', json=login_data)
    print(f'Login Status: {response.status_code}')
    
    if response.status_code == 200:
        token = response.json().get('token')
        print(f'Got token: {token[:30]}...' if token else 'No token')
        
        if token:
            # Test the finance proposals endpoint
            headers = {'Authorization': f'Bearer {token}'}
            finance_response = requests.get('http://127.0.0.1:8000/api/finance/proposals', headers=headers)
            print(f'\nFinance API Status: {finance_response.status_code}')
            
            if finance_response.status_code == 200:
                data = finance_response.json()
                proposals = data.get('proposals', [])
                print(f'Found {len(proposals)} proposals')
                for p in proposals[:3]:
                    title = p.get('title', 'No title')
                    status = p.get('status', 'No status')
                    print(f'  - {title} ({status})')
            else:
                print(f'Finance API Error: {finance_response.text}')
    else:
        print(f'Login failed: {response.text}')
except Exception as e:
    print(f'Error: {e}')
