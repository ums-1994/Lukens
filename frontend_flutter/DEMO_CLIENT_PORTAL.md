# Client Portal Demo Checklist

Quick notes for a smooth demo of the client-portal side of the app.

Preparation
- Branch: `psb-177-merge-preserve-analytics` (local + origin). Use that branch for demo code.
- Ensure backend is running locally: `cd backend && python -m uvicorn asgi:app --host 127.0.0.1 --port 5000 --reload`
- Ensure frontend is running in Chrome: `cd frontend_flutter && flutter run -d chrome`
- Test account (example): admin@example.com / demo-password (replace with real creds)

Startup checks (do these before the demo starts)
- Open DevTools console for backend logs and frontend console to observe telemetry/analytics calls.
- Verify `High Risk` count on Approver Dashboard shows expected value (comes from `/api/analytics/risk-gate/details`).
- Confirm `Analytics` item is hidden for manager role and visible for admin (Admin Sidebar).
- Navigate to Approvals page and confirm filter args are passed when clicking `View` from dashboard.

Walkthrough order (recommended)
1. Show Dashboard landing (explain what each section surfaces: Pipeline Health, What Needs Attention, Proposals Awaiting Your Approval).
2. Click the 'View' CTA for a row (Blocked / Needs approval / Delayed) — this should open Approvals with a pre-applied filter.
3. Open a proposal from the Approvals list and show the Review flow (only 'Review' action is available on this list view).
4. Show recent approvals panel and open one to demonstrate signed/released state.
5. (If admin) open Admin Sidebar → Analytics and show analytics page (or explain why managers don't see it).

Talking points
- We use an authoritative analytics endpoint for High Risk counts (`/api/analytics/risk-gate/details`) to avoid client-side parsing mismatches.
- Dashboard CTAs are instrumented with `TelemetryService.trackEvent` (currently logs to console; can forward to telemetry backend).
- Managers see a simplified UI (no Analytics card) to reduce noise and risk of accidental data access.
- Feature-flag placeholder exists to roll out this dashboard safely.

Troubleshooting quick tips
- If High Risk shows 0 but analytics endpoint reports blocked items: check console network tab for `/api/analytics/risk-gate/details` and auth token header.
- If tests hang or widget tests time out: run frontend locally and verify `flutter doctor` and Chrome are available.
- If local backend is unavailable, demo using mocked AppState: set `AuthService.setUserData(...)` and use `TestAppState` for deterministic UI.

Commands recap
```powershell
cd C:/Users/d/Documents/new/backend
python -m uvicorn asgi:app --host 127.0.0.1 --port 5000 --reload

cd C:/Users/d/Documents/new/frontend_flutter
flutter run -d chrome
```

Notes for follow-up
- I can prepare a short slide or scripted demo transcript if you want exact wording for each step.
- I can record a short 2–3 minute screencast sample for practice.
