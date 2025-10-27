# 🔧 Quick Fix: Collaboration Port Issue

## Problem
Collaboration links go to `localhost:8080` (database) instead of `localhost:8081` (Flutter app).

---

## ✅ Solution (Follow in Order)

### Step 1: Stop Backend (if running)
Press `Ctrl+C` in the terminal where backend is running.

### Step 2: Verify `.env` File
Check that `backend/.env` contains:
```env
FRONTEND_URL=http://localhost:8081
```
✅ This has been created for you!

### Step 3: Restart Backend
```bash
cd backend
python app.py
```

Look for this line in the output:
```
✅ Flask app running on http://localhost:8000
```

### Step 4: Start Flutter on Port 8081
In a NEW terminal:
```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081
```

Look for:
```
Launching lib/main.dart on Chrome in debug mode...
```

Browser should open to: `http://localhost:8081`

### Step 5: Send NEW Invitation
⚠️ **Important:** The old email has the wrong link!

1. Log in to your app at `http://localhost:8081`
2. Open a proposal
3. Click "Share" button
4. Send a **NEW** invitation
5. Check your email for the new invitation
6. The link should now say `localhost:8081`

### Step 6: Test the New Link
Click the link in the NEW email.
Should open: `http://localhost:8081/#/collaborate?token=...`
Should show: Guest collaboration page ✅

---

## 🐛 Troubleshooting

### "Port 8081 already in use"
```bash
# Find and kill the process
netstat -ano | findstr :8081
taskkill /PID <process_id> /F
```

### "Still showing database page"
- Make sure you're clicking the **NEW** invitation link
- Old emails still have `localhost:8080`
- Send a fresh invitation after restarting backend

### "Backend won't start"
Check the `.env` file exists:
```bash
cd backend
Get-Content .env
```

Should show `FRONTEND_URL=http://localhost:8081`

---

## ✨ Final Check

After following all steps:

1. ✅ Backend running on `http://localhost:8000`
2. ✅ Frontend running on `http://localhost:8081`
3. ✅ New invitation sent
4. ✅ Email link says `localhost:8081`
5. ✅ Clicking link shows Flutter app (not database)

---

**Remember:** Always send a NEW invitation after changing the port configuration!

