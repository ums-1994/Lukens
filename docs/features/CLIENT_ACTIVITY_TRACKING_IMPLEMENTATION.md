# Client Activity Tracking & Time-Spent Insights - Implementation Status

## ✅ Completed Implementation

### 1. Database Schema
**File:** `backend/database_schema.sql`

Added two new tables:
- **`proposal_client_activity`** - Logs all client events (open, close, view_section, download, sign, comment)
- **`proposal_client_session`** - Tracks time spent per session

Both tables include proper indexes for performance.

### 2. Backend API Endpoints

#### Client Activity Tracking (`backend/api/routes/client.py`)
- **POST `/api/client/activity`** - Log client activity events
- **POST `/api/client/session/start`** - Start a new tracking session
- **POST `/api/client/session/end`** - End session and calculate time spent

#### Analytics Endpoint (`backend/api/routes/creator.py`)
- **GET `/api/proposals/<id>/analytics`** - Get comprehensive analytics including:
  - Total time spent
  - Views count
  - Downloads count
  - Signs count
  - Comments count
  - First open / Last open timestamps
  - Section-by-section time spent
  - Full activity timeline
  - Session history

### 3. Frontend Client Tracking

**File:** `frontend_flutter/lib/pages/client/client_proposal_viewer.dart`

Added automatic event tracking:
- ✅ **`open`** - Logged when proposal is opened
- ✅ **`close`** - Logged when proposal is closed
- ✅ **`download`** - Logged when PDF download is clicked
- ✅ **`sign`** - Logged when signing modal is opened
- ✅ **`comment`** - Logged when comment is submitted
- ✅ **Session tracking** - Automatically starts on open, ends on close

### 4. API Service Method

**File:** `frontend_flutter/lib/api.dart`

Added:
- ✅ `getProposalAnalytics(String proposalId)` - Fetches analytics data

---

## 🚧 Remaining Implementation

### 1. Insights Panel Modal (UI Component)

**Location:** Create new file `frontend_flutter/lib/pages/shared/proposal_insights_modal.dart`

**Features Needed:**
- Two tabs: **Activity** and **Analytics**
- **Activity Tab:**
  - Timeline of all events (most recent first)
  - Format: "4h ago – Client viewed the document"
  - Event types: open, close, view_section, download, sign, comment
  - Show client name/initials for each event
  
- **Analytics Tab:**
  - Total Time Spent: "14m 12s"
  - Views: 4
  - Downloads: 1
  - Signs: 1
  - Comments: 2
  - First Open: "2025-11-20 12:10"
  - Last Open: "2025-11-20 12:24"
  - Section Times: Breakdown by section (if available)
  - Sessions Count: Number of viewing sessions

**Design:**
- Modal dialog (similar to Proposify style)
- Dark/light theme compatible
- Scrollable content
- Close button

### 2. Dashboard Integration

**File:** `frontend_flutter/lib/pages/creator/creator_dashboard_page.dart`

**Updates Needed:**
1. Modify `_buildProposalItem` to:
   - Accept full proposal object (not just title/subtitle)
   - Show client initials badge for "Sent to Client" proposals
   - Show last activity timestamp
   - Add "Insights" button for "Sent to Client" proposals

2. Add method to open insights modal:
   ```dart
   void _showInsightsModal(Map<String, dynamic> proposal) {
     showDialog(
       context: context,
       builder: (context) => ProposalInsightsModal(
         proposalId: proposal['id'].toString(),
         proposalTitle: proposal['title'] ?? 'Untitled',
       ),
     );
   }
   ```

3. Update proposal card to show:
   - Status badge (Sent, Viewed, Signed)
   - Client initials avatar
   - Last activity: "Viewed 3m ago"
   - Insights button (only for "Sent to Client")

### 3. Helper Functions Needed

**Client Initials:**
```dart
String _getClientInitials(Map<String, dynamic> proposal) {
  final clientName = proposal['client_name'] ?? proposal['client'] ?? '';
  if (clientName.isEmpty) return '?';
  final parts = clientName.split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return clientName[0].toUpperCase();
}
```

**Format Relative Time:**
```dart
String _formatRelativeTime(String? timestamp) {
  if (timestamp == null) return 'Never';
  try {
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  } catch (e) {
    return 'Unknown';
  }
}
```

---

## 📋 Implementation Checklist

- [x] Database tables created
- [x] Backend API endpoints for activity logging
- [x] Backend API endpoint for analytics
- [x] Client proposal viewer tracking events
- [x] API service method for analytics
- [ ] Create insights panel modal component
- [ ] Update dashboard proposal cards
- [ ] Add client initials display
- [ ] Add last activity timestamp
- [ ] Add insights button to proposal cards
- [ ] Test end-to-end flow

---

## 🧪 Testing Steps

1. **Test Activity Tracking:**
   - Open a proposal as a client
   - Verify "open" event is logged
   - Download PDF, verify "download" event
   - Add comment, verify "comment" event
   - Close proposal, verify "close" event and session end

2. **Test Analytics:**
   - As admin/creator, open insights for a "Sent to Client" proposal
   - Verify analytics data displays correctly
   - Check activity timeline shows all events
   - Verify time calculations are accurate

3. **Test Dashboard:**
   - View "Sent to Client" proposals
   - Verify client initials appear
   - Verify last activity timestamp
   - Click insights button, verify modal opens
   - Verify data loads correctly

---

## 📝 Notes

- The system tracks both individual events and session time
- Analytics are calculated server-side for accuracy
- All timestamps are stored in UTC and converted to local time in UI
- Client ID is resolved from email/token for proper tracking
- The system handles both UUID and integer proposal IDs for compatibility

---

## 🎯 Next Steps

1. Create `proposal_insights_modal.dart` component
2. Update `creator_dashboard_page.dart` to show insights button
3. Add client initials and last activity to proposal cards
4. Test the complete flow
5. Add error handling and loading states

