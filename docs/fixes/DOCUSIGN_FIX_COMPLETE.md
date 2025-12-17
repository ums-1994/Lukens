# ============================================================================
# DOCUSIGN FIX - COMPLETE GUIDE
# ============================================================================

## ROOT CAUSES IDENTIFIED:

1. ❌ ACCOUNT_ID MISMATCH
   - Your .env has: DOCUSIGN_ACCOUNT_ID=70784c46-78c0-45af-8207-f4b8e8a43ea
   - This looks INCOMPLETE (missing characters at end)
   - UUID format should be: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 chars)
   
2. ❌ ACCOUNT_ID NOT EXTRACTED FROM JWT
   - Current code tries to read ACCOUNT_ID from .env
   - But account_id should come from DocuSign JWT response
   - If .env account_id is wrong/incomplete, it becomes NULL
   - Passing NULL to DocuSign API = ERROR: 'Invalid value specified for accountId'

3. ❌ JWT RESPONSE NOT PARSED COMPLETELY
   - get_docusign_jwt_token() only returns access_token
   - Doesn't extract account_id from response.accounts array

## SOLUTION:

### STEP 1: Update get_docusign_jwt_token() Function
Replace in backend/app.py around line 850:

---START REPLACE---

def get_docusign_jwt_token():
    '''
    Get DocuSign access token using JWT authentication
    Returns: dict with access_token and account_id
    '''
    if not DOCUSIGN_AVAILABLE:
        raise Exception('DocuSign SDK not installed')
    
    try:
        integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
        user_id = os.getenv('DOCUSIGN_USER_ID')
        auth_server = os.getenv('DOCUSIGN_AUTH_SERVER', 'account-d.docusign.com')
        private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', './docusign_private.key')

        if not all([integration_key, user_id]):
            raise Exception('DocuSign credentials not configured')

        # Read private key
        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()

        # Create API client
        api_client = ApiClient()
        api_client.set_base_path(f'https://{auth_server}')

        # Request JWT token
        response = api_client.request_jwt_user_token(
            client_id=integration_key,
            user_id=user_id,
            oauth_host_name=auth_server,
            private_key_bytes=private_key,
            expires_in=3600,
            scopes=['signature', 'impersonation']
        )

        # FIXED: Extract account_id from JWT response
        account_id = response.accounts[0].account_id if response.accounts else None
        
        if not account_id:
            raise Exception('No account_id returned from DocuSign JWT response')
        
        print(f'✅ DocuSign JWT authenticated. Account ID: {account_id}')
        
        return {
            'access_token': response.access_token,
            'account_id': account_id
        }

    except Exception as e:
        print(f'❌ Error getting DocuSign JWT token: {e}')
        traceback.print_exc()
        raise

---END REPLACE---

### STEP 2: Update create_docusign_envelope() Function
Replace in backend/app.py around line 900:

---START REPLACE---

def create_docusign_envelope(proposal_id, pdf_bytes, signer_name, signer_email, signer_title, return_url):
    '''
    Create DocuSign envelope with embedded signing
    '''
    if not DOCUSIGN_AVAILABLE:
        raise Exception('DocuSign SDK not installed')

    try:
        # FIXED: Get both access token AND account_id from JWT response
        auth_data = get_docusign_jwt_token()
        access_token = auth_data['access_token']
        account_id = auth_data['account_id']
        
        base_path = os.getenv('DOCUSIGN_BASE_PATH', 'https://demo.docusign.net/restapi')

        print(f'ℹ️  Using account_id: {account_id}')
        print(f'ℹ️  Using base_path: {base_path}')

        # Create API client
        api_client = ApiClient()
        api_client.host = base_path
        api_client.set_default_header('Authorization', f'Bearer {access_token}')

        # Create document
        document = Document(
            document_base64=base64.b64encode(pdf_bytes).decode('utf-8'),
            name=f'Proposal_{proposal_id}.pdf',
            file_extension='pdf',
            document_id='1'
        )
        
        # Create signer
        sign_here = SignHere(
            anchor_string='/sig1/',
            anchor_units='pixels',
            anchor_y_offset='10',
            anchor_x_offset='20'
        )

        tabs = Tabs(sign_here_tabs=[sign_here])

        signer = Signer(
            email=signer_email,
            name=signer_name,
            recipient_id='1',
            routing_order='1',
            client_user_id='1000',
            tabs=tabs
        )

        if signer_title:
            signer.note = f'Title: {signer_title}'

        recipients = Recipients(signers=[signer])

        envelope_definition = EnvelopeDefinition(
            email_subject=f'Please sign: Proposal #{proposal_id}',
            documents=[document],
            recipients=recipients,
            status='sent'
        )

        # FIXED: Pass account_id from JWT response (not from .env)
        envelopes_api = EnvelopesApi(api_client)
        results = envelopes_api.create_envelope(account_id, envelope_definition=envelope_definition)
        envelope_id = results.envelope_id

        print(f'✅ DocuSign envelope created: {envelope_id}')

        recipient_view_request = RecipientViewRequest(
            authentication_method='none',
            client_user_id='1000',
            recipient_id='1',
            return_url=return_url,
            user_name=signer_name,
            email=signer_email
        )

        view_results = envelopes_api.create_recipient_view(
            account_id,
            envelope_id,
            recipient_view_request=recipient_view_request
        )

        signing_url = view_results.url

        print(f'✅ Embedded signing URL created: {signing_url}')

        return {
            'envelope_id': envelope_id,
            'signing_url': signing_url
        }

    except ApiException as e:
        print(f'❌ DocuSign API error: {e}')
        print(f'Account ID used: {account_id}')
        raise
    except Exception as e:
        print(f'❌ Error creating DocuSign envelope: {e}')
        traceback.print_exc()
        raise

---END REPLACE---

### STEP 3: Update .env file
Keep the DOCUSIGN_ACCOUNT_ID in case of fallback, but it will be overridden by JWT response:

DOCUSIGN_INTEGRATION_KEY=db0483f5-8f70-45d9-a949-d300cdddc1cd
DOCUSIGN_USER_ID=1b972593-a0d0-403b-adbe-d14c9a7bbd2f
DOCUSIGN_ACCOUNT_ID=70784c46-78c0-45af-8207-f4b8e8a43ea
DOCUSIGN_PRIVATE_KEY_PATH=./docusign_private.key
DOCUSIGN_BASE_PATH=https://demo.docusign.net/restapi
DOCUSIGN_AUTH_SERVER=account-d.docusign.com

## TESTING:

1. Restart backend:
   python app.py

2. Try send for signature again - should now work with account_id from JWT

3. Check logs for:
   ✅ DocuSign JWT authenticated. Account ID: [UUID]
   ✅ DocuSign envelope created: [ENVELOPE_ID]

## WHAT WAS WRONG:

❌ OLD CODE:
  account_id = os.getenv('DOCUSIGN_ACCOUNT_ID')  # Returns NULL if not set or incomplete
  results = envelopes_api.create_envelope(account_id, ...)  # Passes NULL → Error 400

✅ NEW CODE:
  auth_data = get_docusign_jwt_token()  # Extracts account_id from JWT response
  account_id = auth_data['account_id']  # Gets VALID account_id from DocuSign
  results = envelopes_api.create_envelope(account_id, ...)  # Passes VALID UUID → Success

