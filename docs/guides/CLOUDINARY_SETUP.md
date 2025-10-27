# Cloudinary Integration Setup Guide

This guide will help you set up Cloudinary for storing templates, images, and other media files.

## Step 1: Create a Cloudinary Account

1. Visit [https://cloudinary.com/users/register/free](https://cloudinary.com/users/register/free)
2. Sign up for a free account
3. Complete email verification
4. Go to your **Dashboard** to find your credentials

## Step 2: Get Your Cloudinary Credentials

1. Log in to your Cloudinary Dashboard
2. Look for the **Account Details** section
3. Copy these three values:
   - **Cloud Name** - Your account identifier
   - **API Key** - For authentication
   - **API Secret** - For authentication (keep this private!)

## Step 3: Update .env File

Update your `.env` file in the root directory with your Cloudinary credentials:

```env
# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

**Example:**
```env
CLOUDINARY_CLOUD_NAME=djkqw892jd
CLOUDINARY_API_KEY=123456789123456
CLOUDINARY_API_SECRET=abcdefghijklmnopqrstuvwxyz123
```

## Step 4: Install Python Dependencies

Run this command in your backend directory:

```bash
pip install -r requirements.txt
```

The setup now includes `cloudinary==1.36.0` package.

## Step 5: Install Flutter Dependencies

Run this command in your Flutter project:

```bash
flutter pub get
```

This installs:
- `cloudinary_flutter: ^2.0.4` - For frontend display optimization
- `dio: ^5.3.1` - For HTTP requests

## Step 6: Restart Your Backend

1. Stop your Python backend if it's running
2. Start it again:
   ```bash
   python start_python_backend.py
   ```
   or
   ```bash
   uvicorn backend.app:app --reload --host 0.0.0.0 --port 8000
   ```

## Step 7: Test the Integration

### Test Backend Upload Endpoint

Use this cURL command to test image upload:

```bash
curl -X POST http://localhost:8000/upload/image \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -F "file=@/path/to/your/image.jpg"
```

You should get a response like:
```json
{
  "success": true,
  "url": "https://res.cloudinary.com/your_cloud_name/image/upload/...",
  "public_id": "proposal_builder/images/your_image",
  "filename": "image.jpg",
  "size": 12345
}
```

### Test Flutter Upload

1. Hot restart your Flutter app
2. Go to **Content Library** → **Images**
3. Click **Upload** button
4. Select an image file
5. Wait for upload to complete
6. Image should appear in the list with a Cloudinary URL

## API Endpoints

### 1. Upload Image to Cloudinary
```
POST /upload/image
```
**Multipart Form Data:**
- `file` - Image file (jpg, png, gif, webp, svg)

**Response:**
```json
{
  "success": true,
  "url": "https://res.cloudinary.com/...",
  "public_id": "proposal_builder/images/...",
  "filename": "image.jpg",
  "size": 12345
}
```

### 2. Upload Template to Cloudinary
```
POST /upload/template
```
**Multipart Form Data:**
- `file` - Template file (any format)

### 3. Get Upload Signature
```
POST /upload/signature
```
**JSON Body:**
```json
{
  "public_id": "unique_identifier"
}
```

**Response:**
```json
{
  "success": true,
  "signature": "abc123...",
  "timestamp": 1234567890,
  "public_id": "unique_identifier",
  "folder": "proposal_builder"
}
```

### 4. Delete File from Cloudinary
```
DELETE /upload/{public_id}
```

**Response:**
```json
{
  "success": true,
  "message": "File deleted from Cloudinary"
}
```

## File Structure in Cloudinary

Your uploads will be organized as:
```
proposal_builder/
├── images/
│   ├── logo.jpg
│   ├── diagram.png
│   └── ...
├── templates/
│   ├── template1.docx
│   ├── template2.pdf
│   └── ...
└── ...
```

## Security Features

✅ **Private Access** - Files require authentication token to access
✅ **Folder Organization** - Files organized by type
✅ **API Secret Protection** - Stored securely in backend
✅ **Signed Requests** - Optional signatures for direct uploads

## Troubleshooting

### "Cloudinary credentials not configured"
- Make sure `.env` file has all three Cloudinary variables
- Restart your backend after updating `.env`

### "403 Unauthorized" errors
- Check your API Key and API Secret are correct
- Make sure your Cloudinary account is active

### "Upload fails silently"
- Check browser console for errors
- Check backend logs for exceptions
- Verify file size isn't too large (default 100MB limit)

### Images don't appear in Content Library
- Make sure upload completed (check response)
- Verify `notifyListeners()` was called in Flutter
- Check that `public_id` is stored with content

## Pricing & Limits

**Free Tier:**
- 25GB storage
- 25GB monthly bandwidth
- Unlimited API requests
- Automatic image optimization
- CDN delivery

[View Cloudinary Pricing](https://cloudinary.com/pricing)

## Next Steps

1. Configure upload transformations (resize, compress, etc.)
2. Set up image optimization rules
3. Enable CDN caching for faster delivery
4. Set up webhooks for upload events
5. Configure access control tokens

## References

- [Cloudinary API Documentation](https://cloudinary.com/documentation)
- [Python SDK Docs](https://cloudinary.com/documentation/python_integration)
- [Flutter Widget Integration](https://pub.dev/packages/cloudinary_flutter)

---

**Questions?** Check the backend logs at `backend/logs/` or review the implementation in:
- `backend/cloudinary_config.py` - Configuration and helper functions
- `backend/app.py` - API endpoints (lines 2806-2889)
- `frontend_flutter/lib/api.dart` - Flutter client methods (lines 605-700)
- `frontend_flutter/lib/pages/creator/content_library_page.dart` - Upload UI (lines 518-621)