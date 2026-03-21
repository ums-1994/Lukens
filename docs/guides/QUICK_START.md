# Quick Start Guide - AI Features
## Get Your Demo Running in 5 Minutes

---

## 🚀 Step 1: Start the Backend (1 minute)

```bash
# Navigate to backend directory
cd "C:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend"

# Start the server
uvicorn app:app --reload --port 5000
```

**Expected Output**:
```
INFO:     Uvicorn running on http://127.0.0.1:5000
INFO:     Application startup complete.
```

✅ Backend is now running with AI endpoints!

---

## 🧪 Step 2: Test AI Features (2 minutes)

### Option A: Using PowerShell

```powershell
# Test AI status
Invoke-WebRequest -Uri "http://localhost:5000/ai/status" -Method GET

# Expected: {"ai_enabled":true,"model":"anthropic/claude-3.5-sonnet","provider":"OpenRouter"}
```

### Option B: Using Python Test Script

```bash
# In backend directory
python test_ai_service.py
```

**Expected Output**:
```
============================================================
Testing AI Service Integration
============================================================

✓ AI Service Initialized Successfully
✓ Using Model: anthropic/claude-3.5-sonnet
✓ Base URL: https://openrouter.ai/api/v1

============================================================
Test 1: Risk Analysis (Wildcard Challenge)
============================================================

✓ Risk Score: 75/100
✓ Risk Level: high
✓ Can Release: False
✓ Issues Found: 5

============================================================
Test 2: Content Generation
============================================================

✓ Generated Content (2141 characters)
...
```

✅ AI features are working!

---

## 🎨 Step 3: Test from Frontend (2 minutes)

### Start Flutter App

```bash
# Navigate to frontend directory
cd "C:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\frontend_flutter"

# Run the app
flutter run -d chrome
```

### Check AI Status

1. Login to the app
2. Navigate to **Admin** → **AI Configuration**
3. Click **"Check Backend Status"**
4. Should show: "Backend AI is configured" ✅

---

## 📝 Step 4: Test with Postman (Optional)

### Get Authentication Token

```http
POST http://localhost:5000/auth/login
Content-Type: application/json

{
  "email": "your-email@example.com",
  "password": "your-password"
}
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### Test Risk Analysis

```http
POST http://localhost:5000/ai/analyze-risks
Authorization: Bearer YOUR_TOKEN_HERE
Content-Type: application/json

{
  "proposal_id": "your-proposal-id"
}
```

**Response**:
```json
{
  "analysis": {
    "overall_risk_level": "high",
    "can_release": false,
    "risk_score": 75,
    "issues": [
      {
        "category": "incomplete_content",
        "severity": "high",
        "section": "Scope & Deliverables",
        "description": "Scope contains vague language",
        "recommendation": "Make deliverables specific"
      }
    ],
    "summary": "Proposal has 5 critical issues",
    "required_actions": ["Complete Assumptions section", "Clarify scope"]
  }
}
```

### Test Content Generation

```http
POST http://localhost:5000/ai/generate-section
Authorization: Bearer YOUR_TOKEN_HERE
Content-Type: application/json

{
  "section_type": "executive_summary",
  "context": {
    "client_name": "Acme Corporation",
    "project_type": "Web Development",
    "industry": "E-commerce"
  }
}
```

**Response**:
```json
{
  "generated_content": "Executive Summary\n\nAcme Corporation seeks to strengthen its e-commerce presence..."
}
```

---

## 🎬 Demo Script for Hackathon

### 1. Show Backend is Running (30 seconds)

- Open browser to `http://localhost:5000/docs`
- Show FastAPI Swagger UI with AI endpoints
- Point out: `/ai/analyze-risks`, `/ai/generate-section`, etc.

### 2. Run Test Script (1 minute)

```bash
python backend/test_ai_service.py
```

- Show AI service initializes
- Show risk analysis detecting issues
- Show content generation creating text
- Show quality scores and improvements

### 3. Demonstrate via Postman (2 minutes)

**Risk Analysis**:
- Show request with proposal data
- Show response with risk score: 75/100
- Show multiple issues detected
- Show `can_release: false` (Wildcard Challenge!)

**Content Generation**:
- Show request with context
- Show AI-generated professional content
- Highlight quality and relevance

**Content Improvement**:
- Show poor content: "We will do the project. It will be good."
- Show quality score: 15/100
- Show specific improvement suggestions
- Show improved version

### 4. Explain Architecture (1 minute)

- **Backend**: Python FastAPI with OpenRouter integration
- **AI Model**: Claude 3.5 Sonnet (state-of-the-art)
- **Security**: API keys on backend, JWT authentication
- **Features**: 5 AI-powered capabilities

### 5. Show Code (1 minute)

Open `backend/ai_service.py`:
- Show `analyze_proposal_risks()` method
- Explain compound risk detection
- Show JSON response structure

### 6. Explain Wildcard Challenge Solution (1 minute)

**Compound Risk Gate**:
- AI analyzes entire proposal
- Detects multiple small deviations:
  - ❌ Missing assumptions
  - ❌ Incomplete bios
  - ⚠️ Vague scope
  - ⚠️ Aggressive timeline
- Aggregates into risk score (0-100)
- Blocks release if score > 60
- Provides actionable recommendations

**Demo**:
- Show proposal with issues → Risk: 75/100 → BLOCKED
- Fix issues → Risk: 15/100 → READY
- Release gate opens!

---

## 🐛 Troubleshooting

### Backend won't start

**Error**: `ModuleNotFoundError: No module named 'requests'`
```bash
pip install -r backend/requirements.txt
```

**Error**: `OPENROUTER_API_KEY not found`
- Check `.env` file exists in backend directory
- Verify `OPENROUTER_API_KEY=sk-or-v1-...` is present

### AI endpoints return errors

**Error**: `401 Unauthorized`
- You need to login first and get JWT token
- Add `Authorization: Bearer YOUR_TOKEN` header

**Error**: `503 Service Unavailable`
- Check OpenRouter API key is valid
- Check internet connection
- Try again (OpenRouter might be rate limiting)

### Frontend can't connect

**Error**: `Failed to connect to localhost:5000`
- Make sure backend is running
- Check backend is on port 5000
- Check CORS settings in backend

---

## 📚 Documentation Reference

| Document | Purpose |
|----------|---------|
| `AI_INTEGRATION_SUMMARY.md` | Complete feature documentation |
| `UI_INTEGRATION_GUIDE.md` | Step-by-step UI integration code |
| `IMPLEMENTATION_STATUS.md` | Current status and next steps |
| `QUICK_START.md` | This file - get started fast |

---

## 🎯 Key Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/ai/status` | GET | Check if AI is enabled |
| `/ai/analyze-risks` | POST | Analyze proposal risks (Wildcard) |
| `/ai/generate-section` | POST | Generate content with AI |
| `/ai/improve-content` | POST | Improve existing content |
| `/ai/check-compliance` | POST | Check compliance |

All endpoints except `/ai/status` require authentication.

---

## 💡 Quick Tips

1. **Response Time**: AI calls take 3-8 seconds - show loading indicators
2. **Error Handling**: Always have fallback if AI fails
3. **Context Matters**: More context = better AI results
4. **Cost**: Each AI call costs $0.02-0.05
5. **Caching**: Consider caching results to reduce costs

---

## ✅ Checklist

Before your demo:

- [ ] Backend server is running (`uvicorn app:app --reload`)
- [ ] Test script runs successfully (`python test_ai_service.py`)
- [ ] AI status endpoint returns `ai_enabled: true`
- [ ] You have a valid JWT token for authenticated endpoints
- [ ] You have Postman collection ready (or curl commands)
- [ ] You understand the Wildcard Challenge solution
- [ ] You can explain the architecture
- [ ] You have example proposals to test with

---

## 🎉 You're Ready!

Your AI integration is working and ready to demo. The backend is solid, the features are powerful, and you're addressing both the mandatory AI requirement and the Wildcard Challenge.

**Good luck with your hackathon! 🚀**

---

## 📞 Quick Commands Reference

```bash
# Start backend
cd backend && uvicorn app:app --reload

# Test AI
cd backend && python test_ai_service.py

# Start frontend
cd frontend_flutter && flutter run -d chrome

# Check AI status
curl http://localhost:5000/ai/status

# View API docs
# Open browser: http://localhost:5000/docs
```

---

**Everything you need is ready. Now go win that hackathon! 🏆**