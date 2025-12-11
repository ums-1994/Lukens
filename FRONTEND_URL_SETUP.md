# Frontend URL Configuration

Set the `FRONTEND_URL` environment variable to `https://sowbuilders.netlify.app` in the following places:

## 1. Local Development (.env file)

Add this line to your `backend/.env` file:

```env
FRONTEND_URL=https://sowbuilders.netlify.app
```

**Important:** Make sure there are no leading or trailing spaces around the `=` sign.

## 2. Production (Render.com Dashboard)

1. Go to your Render.com dashboard: https://dashboard.render.com
2. Navigate to your **lukens-backend** service
3. Click on **Environment** in the left sidebar
4. Click **Add Environment Variable**
5. Set:
   - **Key:** `FRONTEND_URL`
   - **Value:** `https://sowbuilders.netlify.app`
6. Click **Save Changes**
7. Your service will automatically redeploy

## What This Does

The `FRONTEND_URL` is used to generate:
- Collaboration invitation links
- DocuSign return URLs
- Client proposal access links
- Email notification links

Without this set, the system will default to `https://sowbuilders.netlify.app`, but it's better to set it explicitly for clarity and flexibility.

## Verification

After setting the environment variable, you can verify it's working by:
1. Checking the logs when sending collaboration invitations - you should see:
   ```
   🔗 Collaboration invitation URL: https://sowbuilders.netlify.app/#/collaborate?token=...
   ```
2. Testing a collaboration invitation - the link should point to your Netlify frontend, not localhost

