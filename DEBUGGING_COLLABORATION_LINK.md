# 🔍 How to Debug the Collaboration Link

## Step-by-Step Process

### Step 1: Find the Email
Open your email with subject: "You've been invited to collaborate on..."

### Step 2: Click the Blue Button
Click the **"Open Proposal"** button in the email

### Step 3: NEW TAB Opens
A new browser tab will open with a URL like:
```
http://localhost:8081/#/collaborate?token=VBpnF8WdDVhB0d82lpk8WCNg9dTTbUdKLBWqwOIVKpI
```

### Step 4: Open Console on the NEW TAB
**Important:** On the NEW TAB (not the email tab!)
- Press **F12** 
- Click **Console** tab

### Step 5: Check for Debug Messages
You should see messages like:
```
🔍 AuthWrapper - Full URL: http://localhost:8081/#/collaborate?token=...
🔍 AuthWrapper - Hash: #/collaborate?token=...
🔍 AuthWrapper - Search: 
🔍 Is Collaboration: true, Has Token: true
✅ Detected collaboration URL - showing GuestCollaborationPage
```

---

## 📸 What to Look For

### Good Signs ✅
```
✅ Detected collaboration URL - showing GuestCollaborationPage
🔍 Full URL: http://localhost:8081/
📍 Try 3 - Parsing fragment: /collaborate?token=...
✅ Token extracted successfully: VBpnF8WdDVhB0d82...
```

### Bad Signs ❌
```
🔍 Is Collaboration: false, Has Token: false
❌ No access token provided
```

---

## 🎯 Common Mistakes

❌ **Wrong:** Looking at console on Gmail tab  
✅ **Right:** Looking at console on localhost:8081 tab

❌ **Wrong:** Checking console before clicking link  
✅ **Right:** Click link first, THEN check console

❌ **Wrong:** Looking at Flutter terminal  
✅ **Right:** Looking at browser console (F12)

---

## 📋 Quick Checklist

- [ ] Email is open
- [ ] Clicked "Open Proposal" button
- [ ] New tab opened with localhost:8081
- [ ] Pressed F12 on the NEW tab
- [ ] Looking at "Console" tab
- [ ] Can see 🔍 messages

---

## 🔧 Alternative: Check URL First

Before checking console, look at the **address bar** in the new tab.

**Should be:**
```
http://localhost:8081/#/collaborate?token=LONG_TOKEN_HERE
```

**If you see just:**
```
http://localhost:8081/
```

Then the URL is being stripped before loading. Share what you see in the address bar!

---

## 📞 What to Share

**Option 1: Share URL**
Copy the full URL from the address bar in the new tab

**Option 2: Share Console**
Copy the first 10 lines from the console that start with 🔍 or ❌

**Option 3: Share Screenshot**
Take a screenshot showing:
- Address bar with the URL
- Console with the debug messages

---

**Do this now:** Click email link → Check NEW tab's console (F12) → Share messages

