# 📝 DocuSign Embedded Signing Integration

## ✅ What You're Getting

Full **embedded e-signature** capability using DocuSign's API, allowing clients to sign proposals directly inside your app.

---

## 🎯 Implementation Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    SIGNATURE WORKFLOW                         │
├──────────────────────────────────────────────────────────────┤
│  1. User clicks "Send for Signature"                         │
│  2. Backend generates proposal PDF                           │
│  3. Backend creates DocuSign envelope                        │
│  4. Backend requests embedded signing URL                    │
│  5. Frontend opens signing URL in iframe/modal               │
│  6. Client signs inside your app                             │
│  7. DocuSign sends webhook → Backend updates status          │
│  8. Signed PDF stored in database/cloud                      │
│  9. Notifications sent to stakeholders                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 📦 What's Been Added

### Backend (Python/Flask)
- ✅ DocuSign OAuth 2.0 configuration
- ✅ Envelope creation with embedded signing
- ✅ Signature tracking table
- ✅ Webhook handler for events
- ✅ Helper functions for API calls

### Database
- ✅ `proposal_signatures` table
- ✅ Tracks signature status, signer info, timestamps

### API Endpoints
- ✅ `POST /api/proposals/{id}/docusign/send` - Create envelope
- ✅ `POST /api/docusign/webhook` - Handle events
- ✅ `GET /api/proposals/{id}/signatures` - Get signature status

---

## 🔑 Setup Steps

### 1. Create DocuSign Developer Account

1. Go to [https://developers.docusign.com](https://developers.docusign.com)
2. Sign up for a free developer account
3. Create a new app in the **Developer Console**

### 2. Get Your Credentials

```
Integration Key (Client ID): Copy this
Secret Key: Copy this
Account ID: Copy from your account
User ID: Your DocuSign user ID
```

### 3. Configure Redirect URI

Add this to your DocuSign app settings:
```
http://localhost:8081/docusign/callback
https://yourdomain.com/docusign/callback
```

### 4. Generate RSA Key Pair

DocuSign uses **JWT authentication** for server-to-server:

```bash
# Generate private key
openssl genrsa -out docusign_private.key 2048

# Generate public key
openssl rsa -in docusign_private.key -pubout -out docusign_public.key
```

Upload `docusign_public.key` to your DocuSign app.

### 5. Add Environment Variables

In your `.env` file:

```env
# DocuSign Configuration
DOCUSIGN_INTEGRATION_KEY=your_integration_key_here
DOCUSIGN_USER_ID=your_user_id_here
DOCUSIGN_ACCOUNT_ID=your_account_id_here
DOCUSIGN_BASE_PATH=https://demo.docusign.net/restapi
DOCUSIGN_PRIVATE_KEY_PATH=./docusign_private.key
DOCUSIGN_AUTH_SERVER=account-d.docusign.com

# For production, use:
# DOCUSIGN_BASE_PATH=https://na3.docusign.net/restapi
# DOCUSIGN_AUTH_SERVER=account.docusign.com
```

### 6. Install Python SDK

```bash
pip install docusign-esign
```

---

## 🔌 API Usage

### Send Proposal for Signature

```http
POST /api/proposals/123/docusign/send
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "signer_name": "John Client",
  "signer_email": "john@client.com",
  "signer_title": "CEO",
  "return_url": "http://localhost:8081/#/proposals/123?signed=true"
}
```

**Response:**
```json
{
  "envelope_id": "abc-123-xyz",
  "signing_url": "https://demo.docusign.net/Signing/MTRedeem/v1/...",
  "expires_at": "2025-10-29T14:30:00",
  "message": "Envelope created successfully"
}
```

### Check Signature Status

```http
GET /api/proposals/123/signatures
Authorization: Bearer YOUR_TOKEN
```

**Response:**
```json
{
  "signatures": [
    {
      "id": 456,
      "envelope_id": "abc-123-xyz",
      "signer_name": "John Client",
      "signer_email": "john@client.com",
      "status": "completed",
      "sent_at": "2025-10-28T14:00:00",
      "signed_at": "2025-10-28T14:15:00",
      "signed_document_url": "https://..."
    }
  ]
}
```

---

## 🎨 Frontend Implementation

### 1. Send for Signature Button

```dart
ElevatedButton.icon(
  icon: Icon(Icons.draw),
  label: Text('Send for Signature'),
  onPressed: () => _sendForSignature(),
)
```

### 2. Open Signing Modal

```dart
Future<void> _sendForSignature() async {
  // Step 1: Call backend to create envelope
  final response = await http.post(
    Uri.parse('$baseUrl/api/proposals/$proposalId/docusign/send'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'signer_name': clientName,
      'signer_email': clientEmail,
      'signer_title': 'CEO',
      'return_url': 'http://localhost:8081/#/proposals/$proposalId?signed=true',
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final signingUrl = data['signing_url'];
    
    // Step 2: Open signing URL in modal
    _showSigningModal(signingUrl);
  }
}

void _showSigningModal(String signingUrl) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue,
              child: Row(
                children: [
                  Icon(Icons.draw, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Sign Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Iframe with DocuSign signing
            Expanded(
              child: IframeWidget(url: signingUrl),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### 3. Iframe Widget (web)

```dart
import 'dart:html' as html;
import 'dart:ui' as ui;

class IframeWidget extends StatelessWidget {
  final String url;
  
  const IframeWidget({required this.url});
  
  @override
  Widget build(BuildContext context) {
    // Register iframe
    final iframeElement = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    
    // Unique view ID
    final viewId = 'docusign-iframe-${DateTime.now().millisecondsSinceEpoch}';
    
    // Register view
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => iframeElement,
    );
    
    return HtmlElementView(viewType: viewId);
  }
}
```

---

## 🔔 Webhook Handler

DocuSign will send webhook events to: `https://yourdomain.com/api/docusign/webhook`

**Events handled:**
- `envelope-completed` → Signature completed
- `envelope-declined` → Signature declined
- `envelope-voided` → Envelope voided
- `recipient-completed` → Individual signer finished

**Configure webhook in DocuSign:**
1. Go to Settings → Connect
2. Add webhook URL: `https://yourdomain.com/api/docusign/webhook`
3. Select events to receive
4. Generate HMAC key for security

---

## 🧪 Testing

### 1. Test with Demo Account

Use DocuSign demo environment:
```
Base URL: https://demo.docusign.net/restapi
Auth Server: account-d.docusign.com
```

### 2. Test Signing Flow

```bash
# Step 1: Send for signature
curl -X POST http://localhost:8000/api/proposals/1/docusign/send \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "signer_name": "Test Client",
    "signer_email": "test@example.com",
    "signer_title": "CEO"
  }'

# Step 2: Open signing_url in browser
# Sign the document

# Step 3: Check status
curl http://localhost:8000/api/proposals/1/signatures \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 📊 Status Flow

```
┌─────────────────────────────────────────────────────────┐
│  Status Lifecycle                                       │
├─────────────────────────────────────────────────────────┤
│  Draft → Ready for Signature → Sent for Signature      │
│                                  ↓                       │
│                           In Progress (viewing)         │
│                                  ↓                       │
│                    ┌─────────────┴─────────────┐        │
│                    ↓                             ↓       │
│              Completed (signed)           Declined       │
│                    ↓                                     │
│         Signed PDF stored + archived                    │
└─────────────────────────────────────────────────────────┘
```

---

## 💡 Best Practices

1. **Always use HTTPS** in production
2. **Validate webhook signatures** using HMAC
3. **Store envelope IDs** for tracking
4. **Set expiration** on envelopes (default 30 days)
5. **Add branding** to DocuSign templates
6. **Test thoroughly** in demo environment first

---

## 🚀 Production Checklist

- [ ] DocuSign production account created
- [ ] Integration key configured
- [ ] RSA keys generated and uploaded
- [ ] Environment variables set
- [ ] Webhook endpoint configured
- [ ] SSL certificate installed
- [ ] Webhook HMAC validation enabled
- [ ] Error handling implemented
- [ ] Audit logging enabled
- [ ] Tested end-to-end flow

---

## 📚 Resources

- [DocuSign eSignature API Docs](https://developers.docusign.com/docs/esign-rest-api/)
- [Python SDK GitHub](https://github.com/docusign/docusign-python-client)
- [Embedded Signing Guide](https://developers.docusign.com/docs/esign-rest-api/how-to/request-signature-in-app-embedded/)
- [Webhook Events Reference](https://developers.docusign.com/docs/esign-rest-api/esign101/concepts/webhook/)

---

**Your app is now ready for enterprise-grade e-signatures!** 🎊



