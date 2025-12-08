# 🚀 Deploying Lukens to Render

This guide will help you deploy both the backend and frontend of Lukens to Render.

## 📋 Prerequisites

1. A [Render](https://render.com) account
2. Your code pushed to a Git repository (GitHub, GitLab, or Bitbucket)
3. All your API keys and credentials ready

## 🏗️ Architecture

You'll deploy:
- **Backend**: Python/Flask web service
- **Frontend**: Flutter web static site
- **Database**: PostgreSQL (managed by Render)

## 📝 Step-by-Step Deployment

### 1. Prepare Your Repository

Make sure your code is committed and pushed to your Git repository.

### 2. Create PostgreSQL Database

1. Go to your Render dashboard
2. Click **"New +"** → **"PostgreSQL"**
3. Configure:
   - **Name**: `lukens-db`
   - **Database**: `lukens_production`
   - **User**: `lukens_user`
   - **Region**: Choose closest to your users
   - **Plan**: Starter (or higher for production)
4. Click **"Create Database"**
5. **Save the connection details** - you'll need them for the backend

### 3. Deploy Backend Service

1. In Render dashboard, click **"New +"** → **"Web Service"**
2. Connect your Git repository
3. Configure the service:
   - **Name**: `lukens-backend`
   - **Region**: Same as database
   - **Branch**: `main` (or your default branch)
   - **Root Directory**: `backend`
   - **Environment**: `Python 3`
   - **Build Command**: 
     ```bash
     pip install -r requirements.txt
     ```
   - **Start Command**: 
     ```bash
     gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app
     ```
   - **Plan**: Starter (or higher)

4. **Add Environment Variables**:
   Click "Environment" tab and add:

   ```env
   # Database (auto-populated if using Render PostgreSQL)
   DB_HOST=<from database>
   DB_PORT=<from database>
   DB_NAME=<from database>
   DB_USER=<from database>
   DB_PASSWORD=<from database>

   # Python
   PYTHON_VERSION=3.11.0

   # AI Services
   OPENROUTER_API_KEY=your_openrouter_key
   OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
   OPENROUTER_MODEL=anthropic/claude-3.5-sonnet

   # Cloudinary (Image Storage)
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret

   # Email (SMTP)
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USER=your_email@gmail.com
   SMTP_PASS=your_app_password
   SMTP_FROM_EMAIL=your_email@gmail.com

   # DocuSign (if using)
   DOCUSIGN_INTEGRATION_KEY=your_integration_key
   DOCUSIGN_USER_ID=your_user_id
   DOCUSIGN_ACCOUNT_ID=your_account_id
   DOCUSIGN_AUTH_SERVER=https://account-d.docusign.com
   DOCUSIGN_BASE_PATH=https://demo.docusign.net/restapi
   DOCUSIGN_PRIVATE_KEY_PATH=/opt/render/project/src/backend/docusign_private.key
   DOCUSIGN_PUBLIC_KEY_PATH=/opt/render/project/src/backend/docusign_public.key

   # Firebase (if using)
   FIREBASE_CREDENTIALS_PATH=/opt/render/project/src/backend/firebase-service-account.json
   # OR use JSON string:
   # FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}

   # Security
   ENCRYPTION_KEY=your_32_character_encryption_key_here
   SECRET_KEY=your_secret_key_for_sessions

   # CORS (Frontend URL)
   FRONTEND_URL=https://lukens-frontend.onrender.com

   # Optional: Development bypass (set to false in production)
   DEV_BYPASS_AUTH=false
   ```

5. **Upload Secret Files** (if needed):
   - For DocuSign keys: Use Render's file upload or environment variables
   - For Firebase service account: Upload `firebase-service-account.json` or use JSON env var

6. Click **"Create Web Service"**

7. **Wait for deployment** - Render will:
   - Install dependencies
   - Build your app
   - Start the service
   - Give you a URL like `https://lukens-backend.onrender.com`

### 4. Deploy Frontend Static Site

1. In Render dashboard, click **"New +"** → **"Static Site"**
2. Connect your Git repository
3. Configure:
   - **Name**: `lukens-frontend`
   - **Branch**: `main`
   - **Root Directory**: `frontend_flutter`
   - **Build Command**: 
     ```bash
     flutter pub get && flutter build web --release --base-href /
     ```
   - **Publish Directory**: `build/web`

4. **Add Environment Variable**:
   ```env
   REACT_APP_API_URL=https://lukens-backend.onrender.com
   ```
   (Replace with your actual backend URL)

5. Click **"Create Static Site"**

6. **Wait for deployment** - You'll get a URL like `https://lukens-frontend.onrender.com`

### 5. Update Frontend API URL

After backend is deployed, update the frontend:

1. Go to your frontend service in Render
2. Click **"Environment"** tab
3. Update `REACT_APP_API_URL` to your backend URL
4. Click **"Save Changes"** - this will trigger a rebuild

Alternatively, edit `frontend_flutter/web/config.js` and update the default API URL.

### 6. Initialize Database Schema

After backend is running:

1. Go to your backend service logs in Render
2. The schema should auto-initialize on first request
3. Or SSH into the service and run:
   ```bash
   python -c "from api.utils.database import init_database; init_database()"
   ```

## 🔧 Using render.yaml (Alternative Method)

If you prefer Infrastructure as Code:

1. The `render.yaml` file in the root directory defines all services
2. In Render dashboard, go to **"Blueprints"**
3. Click **"New Blueprint"**
4. Connect your repository
5. Render will automatically create all services from `render.yaml`

**Note**: You'll still need to manually add environment variables in the Render dashboard.

## 🔐 Environment Variables Checklist

Make sure you have all these set:

### Required
- ✅ Database credentials (auto-set if using Render PostgreSQL)
- ✅ `PYTHON_VERSION=3.11.0`
- ✅ `FRONTEND_URL` (your frontend Render URL)

### Optional but Recommended
- ✅ `OPENROUTER_API_KEY` (for AI features)
- ✅ `CLOUDINARY_*` (for image uploads)
- ✅ `SMTP_*` (for email sending)
- ✅ `DOCUSIGN_*` (for e-signatures)
- ✅ `FIREBASE_*` (for Firebase auth)
- ✅ `ENCRYPTION_KEY` (for secure data)
- ✅ `SECRET_KEY` (for sessions)

## 🐛 Troubleshooting

### Backend Issues

**"Database connection failed"**
- Check database credentials in environment variables
- Ensure database is running and accessible
- Verify network connectivity

**"Module not found"**
- Check `requirements.txt` includes all dependencies
- Verify build command runs successfully
- Check build logs for missing packages

**"Port already in use"**
- Ensure start command uses `$PORT` environment variable
- Check `gunicorn_conf.py` uses `os.environ.get('PORT')`

### Frontend Issues

**"API calls failing"**
- Verify `REACT_APP_API_URL` is set correctly
- Check browser console for CORS errors
- Ensure backend CORS allows your frontend URL
- Update `FRONTEND_URL` in backend environment variables

**"Build fails"**
- Ensure Flutter SDK is available in build environment
- Check Flutter version compatibility
- Verify all dependencies in `pubspec.yaml`

**"404 on routes"**
- Ensure `--base-href /` is in build command
- Check `index.html` has correct base tag
- Verify static site routing is configured

### Database Issues

**"Schema not initialized"**
- Check backend logs for initialization errors
- Manually run schema initialization
- Verify database user has CREATE permissions

## 📊 Monitoring

- **Logs**: View real-time logs in Render dashboard
- **Metrics**: Monitor CPU, memory, and request rates
- **Alerts**: Set up alerts for service downtime

## 🔄 Updating Deployment

1. Push changes to your Git repository
2. Render automatically detects changes and redeploys
3. Monitor deployment in the dashboard
4. Check logs if deployment fails

## 🚀 Production Checklist

Before going live:

- [ ] All environment variables set
- [ ] Database schema initialized
- [ ] CORS configured correctly
- [ ] SSL certificates active (automatic on Render)
- [ ] Error logging configured
- [ ] Backup strategy for database
- [ ] Monitoring and alerts set up
- [ ] Frontend API URL points to production backend
- [ ] Test all authentication flows
- [ ] Test file uploads (Cloudinary)
- [ ] Test email sending (SMTP)
- [ ] Test DocuSign integration (if using)

## 📞 Support

- Render Docs: https://render.com/docs
- Render Support: https://render.com/support
- Check application logs in Render dashboard for specific errors

## 🎉 Success!

Once deployed, your application will be available at:
- **Frontend**: `https://lukens-frontend.onrender.com`
- **Backend**: `https://lukens-backend.onrender.com`

Update your Firebase/DocuSign webhook URLs to point to your production backend!




