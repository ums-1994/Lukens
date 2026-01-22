"""
Script to find and display the full JWT token for a specific user
"""
import os
import json
from dotenv import load_dotenv

load_dotenv()

def find_user_token(username):
    """Find the full token for a user by username"""
    token_file = os.path.join(os.path.dirname(__file__), 'auth_tokens.json')
    
    print("=" * 80)
    print(f"SEARCHING FOR TOKEN FOR USER: {username}")
    print("=" * 80)
    
    if not os.path.exists(token_file):
        print(f"\n[ERROR] Token file not found: {token_file}")
        print("   Tokens may be stored in memory only or the file hasn't been created yet.")
        return
    
    try:
        with open(token_file, 'r', encoding='utf-8') as f:
            tokens = json.load(f)
        
        print(f"\nTotal tokens in file: {len(tokens)}")
        
        # Search for tokens belonging to this user
        user_tokens = []
        for token, token_data in tokens.items():
            token_username = token_data.get('username', '').lower()
            if username.lower() in token_username or token_username in username.lower():
                user_tokens.append((token, token_data))
        
        if user_tokens:
            print(f"\n[SUCCESS] Found {len(user_tokens)} token(s) for user '{username}':\n")
            
            for i, (token, token_data) in enumerate(user_tokens, 1):
                print("-" * 80)
                print(f"TOKEN #{i}")
                print("-" * 80)
                print(f"\nFull Token:")
                print(token)
                print(f"\nToken Details:")
                print(f"  Username: {token_data.get('username', 'N/A')}")
                print(f"  Created At: {token_data.get('created_at', 'N/A')}")
                print(f"  Expires At: {token_data.get('expires_at', 'N/A')}")
                print(f"\nToken Preview:")
                print(f"  First 50 chars: {token[:50]}...")
                print(f"  Last 50 chars: ...{token[-50:]}")
                print()
        else:
            print(f"\n[WARNING] No tokens found for user '{username}'")
            print("\nAvailable users in token file:")
            usernames = set()
            for token_data in tokens.values():
                usernames.add(token_data.get('username', 'Unknown'))
            for uname in sorted(usernames):
                print(f"  - {uname}")
    
    except json.JSONDecodeError as e:
        print(f"\n[ERROR] Error parsing token file (invalid JSON): {e}")
    except Exception as e:
        print(f"\n[ERROR] Error reading token file: {e}")
        import traceback
        traceback.print_exc()

def list_all_tokens():
    """List all tokens in the file"""
    token_file = os.path.join(os.path.dirname(__file__), 'auth_tokens.json')
    
    print("\n" + "=" * 80)
    print("ALL TOKENS IN FILE")
    print("=" * 80)
    
    if not os.path.exists(token_file):
        print(f"\n[ERROR] Token file not found: {token_file}")
        return
    
    try:
        with open(token_file, 'r', encoding='utf-8') as f:
            tokens = json.load(f)
        
        print(f"\nTotal tokens: {len(tokens)}\n")
        
        for token, token_data in tokens.items():
            username = token_data.get('username', 'Unknown')
            print(f"\nUser: {username}")
            print(f"  Token: {token}")
            print(f"  Created: {token_data.get('created_at', 'N/A')}")
            print(f"  Expires: {token_data.get('expires_at', 'N/A')}")
            print("-" * 80)
    
    except Exception as e:
        print(f"\n[ERROR] Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) > 1:
        username = sys.argv[1]
        find_user_token(username)
    else:
        # Default to searching for "Kgothatso"
        find_user_token("Kgothatso")
        print("\n")
        print("=" * 80)
        print("TIP: To search for a different user, run:")
        print("  python get_user_token.py <username>")
        print("=" * 80)
