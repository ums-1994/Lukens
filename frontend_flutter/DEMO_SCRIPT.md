# Client Portal Demo Script

Use this script to narrate the live demo — speak naturally and follow the steps.

Intro (15s)
- "Hi — thanks for joining. I'll show the Client Portal: how the dashboard surfaces priority items, how approvals work, and how analytics inform risk decisions."
- "I'm running the demo from branch `psb-177-merge-preserve-analytics` with a local backend so you can see live data and logs."

Step 1 — Dashboard Overview (30s)
- "This is the Approver Dashboard. At the top we show summary KPIs: recent approvals, proposals sent to clients, and client approvals."
- "The 'What Needs Attention' area surfaces high-priority items: blocked proposals, delayed items, and items that need approval."

Step 2 — View CTA + Filtered Approvals (30s)
- "I'll click 'View' on the Blocked proposals row — that opens the Approvals page with the 'blocked' filter applied so you see only the blocked items needing review."
- Click and pause briefly to show filtered list and the URL/query args.

Step 3 — Proposal Review Flow (45s)
- "Opening a proposal shows the proposal details and the Review workflow. From the Approvals list we only expose the 'Review' action to reduce accidental approvals; final approve/decline actions happen in the full proposal view."
- Demonstrate opening a proposal, scrolling content, and the review action.

Step 4 — Recent Approvals & Signatures (20s)
- "The Recent Approvals area surfaces recently signed/released proposals so you can quickly audit what's moved through."
- Open a recently signed item to show status and timestamp.

Step 5 — Analytics & High-Risk Counts (30s)
- "For authoritative High Risk counts we rely on the analytics endpoint `/api/analytics/risk-gate/details`. That avoids relying on inconsistent per-proposal fields returned by upstream systems."
- If you're admin: open Analytics from the sidebar and show the risk-gate counts. If you're a manager, note Analytics is hidden to reduce noise.

Closing (15s)
- "That concludes the quick demo. Next steps: we can walk through a specific proposal end-to-end, review telemetry, or discuss how to roll this out behind a feature flag. Any questions?"
