# DocuSign HTTPS Setup Guide

## Problem
DocuSign requires HTTPS for embedded signing. When running on HTTP (`http://localhost:8081`), DocuSign:
- Refuses embedded signing
- Falls back to `/MTRedeem/v1/` redirect
- Shows "Embedded signing requires HTTPS. Opening DocuSign in a new tab instead."

## Current Configuration

### App URL
- **Current**: `http://localhost:8081` ❌
- **Required**: `https://localhost:8081` ✅

### Return URL
- **Current**: `http://localhost:8081/#/client/proposals?token={token}&signed=true` ❌
- **Required**: `https://localhost:8081/#/client/proposals?token={token}&signed=true` ✅

### RecipientViewRequest
```python
{
    "authentication_method": "none",  # ✅ Correct
    "client_user_id": "1000",          # ✅ Correct
    "return_url": "http://..."        # ❌ Must be HTTPS
}
```

## Solution: Set Up HTTPS for Flutter Web

### Step 1: Install mkcert (Certificate Generator)

**Windows:**
```powershell
# Using Chocolatey
choco install mkcert

# Or download from: https://github.com/FiloSottile/mkcert/releases
```

**macOS:**
```bash
brew install mkcert
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt install libnss3-tools
wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
chmod +x mkcert
sudo mv mkcert /usr/local/bin/
```

### Step 2: Create Local CA and Certificate

```bash
# Install local CA
mkcert -install

# Create certificate for localhost
mkcert localhost 127.0.0.1 ::1

# This creates:
# - localhost+2.pem (certificate)
# - localhost+2-key.pem (private key)
```

### Step 3: Configure Flutter Web to Use HTTPS

Create `frontend_flutter/web/certificates/` directory and copy certificates there.

**Option A: Use Flutter's built-in HTTPS support**

Run Flutter with HTTPS:
```bash
cd frontend_flutter
flutter run -d chrome --web-port=8081 --web-hostname=localhost --web-https
```

**Option B: Use a reverse proxy (nginx/Caddy)**

Create `nginx.conf`:
```nginx
server {
    listen 8081 ssl;
    server_name localhost;
    
    ssl_certificate /path/to/localhost+2.pem;
    ssl_certificate_key /path/to/localhost+2-key.pem;
    
    location / {
        proxy_pass http://localhost:8080;  # Flutter dev server
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Step 4: Update Environment Variables

**Backend `.env`:**
```env
FRONTEND_URL=https://localhost:8081
```

**Or set in backend code:**
```python
frontend_url = os.getenv('FRONTEND_URL', 'https://localhost:8081')  # Changed to HTTPS
```

### Step 5: Update DocuSign Redirect URIs

In DocuSign Admin → Apps & Keys → Your Integration Key → Redirect URIs:

Add:
```
https://localhost:8081/*
https://localhost:8081/#/client/proposals*
```

### Step 6: Test

1. Start Flutter with HTTPS:
   ```bash
   flutter run -d chrome --web-port=8081 --web-hostname=localhost --web-https
   ```

2. Verify in browser console:
   ```js
   window.location.protocol  // Should print "https:"
   ```

3. Click "Sign Proposal" - should open embedded signing (not redirect)

## Alternative: Development Workaround (HTTP Only)

If you can't set up HTTPS right now, ensure the new tab opens correctly:

1. The current code uses `web.window.open(url, '_blank')` which should work
2. If the current page still redirects, check browser console for errors
3. Ensure popups are not blocked

**Note**: Embedded signing will NOT work on HTTP. DocuSign will always open in a new tab.

## Verification Checklist

- [ ] App runs on `https://localhost:8081`
- [ ] `window.location.protocol` returns `"https:"`
- [ ] `FRONTEND_URL` environment variable uses `https://`
- [ ] Return URL in `RecipientViewRequest` uses `https://`
- [ ] DocuSign redirect URIs include `https://localhost:8081/*`
- [ ] No HTTP URLs in any DocuSign configuration

## Troubleshooting

### "Certificate not trusted"
- Run `mkcert -install` to install the local CA
- Restart browser after installing CA

### "Connection refused"
- Ensure Flutter is running with `--web-https` flag
- Check firewall isn't blocking port 8081

### "Still redirecting to landing page"
- Verify `window.location.protocol` is `"https:"`
- Check browser console for DocuSign errors
- Verify return URL in network tab is HTTPS



