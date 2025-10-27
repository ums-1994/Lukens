# Document Auto-Save and Backend Integration Guide

## Overview
The blank document editor now includes comprehensive auto-save functionality with version control and full backend integration. Documents are automatically saved to the backend and appear in the proposals page.

## Features Implemented

### 🔄 Auto-Save System
- **Debounced Auto-Save**: Automatically saves 3 seconds after user stops typing
- **Change Detection**: Monitors all text fields (document title, section titles, and content)
- **Smart Triggering**: Only saves when there are actual unsaved changes
- **Background Operation**: Auto-saves without interrupting the user's workflow

### 📚 Version Control
- **Automatic Versioning**: Creates a new version on every save (both auto and manual)
- **Version Metadata**: Tracks:
  - Version number
  - Timestamp
  - Document title
  - All section content
  - Change description
  - Author name
- **Version History Browser**: View and restore previous versions
- **Non-Destructive Restore**: Restoring a version creates a new version

### 💾 Backend Integration
- **API Integration**: Uses `ApiService` to persist documents
- **Create & Update**: 
  - Creates new proposal on first save
  - Updates existing proposal on subsequent saves
- **Structured Storage**: Documents stored as JSON with:
  ```json
  {
    "title": "Document Title",
    "sections": [
      {
        "title": "Section Title",
        "content": "Section content..."
      }
    ],
    "metadata": {
      "currency": "Rand (ZAR)",
      "version": 3,
      "last_modified": "2024-01-15T10:30:00Z"
    }
  }
  ```

### 🎯 UI Enhancements

#### Save Status Indicator
- **Visual Feedback**: Color-coded badge showing save state
  - Orange: Unsaved changes
  - Green: All changes saved
- **Interactive**: Click to view version history
- **Real-time Updates**: Updates instantly when changes are detected

#### Version History Button
- Shows current version number (e.g., "v5")
- Quick access to version history dialog
- Lists all versions with:
  - Version number
  - Timestamp (human-readable: "2m ago", "Just now")
  - Change description
  - Author
  - Document title
  - Current version indicator
  - One-click restore button

#### Action Buttons
1. **Save Button**: Manual save with version creation
2. **Save & Close Button**: Saves and returns to proposals page
3. **Preview Button**: View document without saving
4. **Comments Button**: Collaborate with team members

## How It Works

### Auto-Save Flow
```
1. User types in document
   ↓
2. Change detected → Timer starts (3 seconds)
   ↓
3. User stops typing → Timer completes
   ↓
4. Auto-save triggered
   ↓
5. Save to backend API
   ↓
6. Create new version
   ↓
7. Show success notification
```

### Backend Save Flow
```
1. Check authentication token
   ↓
2. Serialize document content to JSON
   ↓
3. If no proposal ID exists:
   → Create new proposal via API
   → Store returned proposal ID
   
   If proposal ID exists:
   → Update existing proposal via API
   ↓
4. Mark as saved
   ↓
5. Update UI
```

### Version Management
- Versions stored locally in memory during editing session
- Each version captures complete document state
- Restoring a version:
  1. Loads all sections from selected version
  2. Updates all text controllers
  3. Rebuilds UI
  4. Creates new version for the restoration
  5. Marks as unsaved (triggers auto-save)

## Integration with Proposals Page

### Viewing Saved Documents
1. Documents automatically appear in the Proposals Page (`proposals_page.dart`)
2. Saved as "Draft" status by default
3. Shows in proposal list with:
   - Title
   - Last modified date
   - Draft status badge
   - "Edit" button to reopen

### Opening from Proposals
- Clicking "Edit" on a draft proposal opens the blank document editor
- Document ID passed as `proposalId` argument
- Future enhancement: Load existing content from backend

## API Endpoints Used

### Create Proposal
```dart
POST /proposals
Headers: Authorization: Bearer {token}
Body: {
  "title": "Document Title",
  "content": "{serialized JSON}",
  "status": "draft"
}
Response: {
  "id": 123,
  "title": "Document Title",
  ...
}
```

### Update Proposal
```dart
PUT /proposals/{id}
Headers: Authorization: Bearer {token}
Body: {
  "title": "Document Title",
  "content": "{serialized JSON}",
  "status": "draft"
}
```

## User Experience

### Creating a New Document
1. Click "New Proposal" in Proposals Page
2. Select "Start from scratch"
3. Opens blank document editor
4. Start typing
5. Document auto-saves after 3 seconds
6. See "Auto-saved • Version 2" notification
7. Document now appears in Proposals Page

### Editing Session
1. Title changes → Auto-save triggered
2. Section content changes → Auto-save triggered
3. Add new section → Auto-save triggered
4. Visual indicator shows "Unsaved changes" → turns "Saved" when complete

### Saving and Closing
1. Click "Save & Close" button
2. Document saves to backend
3. Shows success message
4. Automatically redirects to Proposals Page
5. New/updated proposal visible in list

## Technical Details

### State Management
```dart
// Auto-save timer
Timer? _autoSaveTimer;

// Change tracking
bool _hasUnsavedChanges = false;

// Version control
List<Map<String, dynamic>> _versionHistory = [];
int _currentVersionNumber = 1;

// Backend integration
int? _savedProposalId;
String? _authToken;
```

### Key Methods
- `_setupAutoSaveListeners()`: Attaches change listeners to all text fields
- `_onContentChanged()`: Triggers debounced auto-save
- `_autoSaveDocument()`: Performs auto-save operation
- `_saveToBackend()`: Saves to backend API (create or update)
- `_serializeDocumentContent()`: Converts document to JSON
- `_createVersion()`: Creates version snapshot
- `_restoreVersion()`: Restores previous version
- `_saveAndClose()`: Saves and navigates to proposals

### Listener Management
- Listeners added when sections are created
- Listeners properly disposed when sections are removed
- New sections automatically get change listeners
- Prevents memory leaks

## Future Enhancements

### Possible Improvements
1. **Load Existing Documents**: Parse and load saved content when editing
2. **Conflict Resolution**: Handle concurrent edits from multiple users
3. **Offline Support**: Queue saves when offline, sync when online
4. **Version Comparison**: Show diff between versions
5. **Auto-recovery**: Restore from crash/accidental close
6. **Cloud Sync**: Real-time sync across devices
7. **Export Versions**: Download specific version as PDF/Word

### Backend Storage Recommendations
1. Store version history in database
2. Implement version pruning (keep last N versions)
3. Add version tags/labels
4. Store content diffs instead of full copies
5. Add version rollback API endpoint

## Testing Checklist

- [ ] Create new document
- [ ] Auto-save after typing
- [ ] Manual save
- [ ] Save & Close navigation
- [ ] View version history
- [ ] Restore previous version
- [ ] Add new sections (listeners work)
- [ ] Delete sections (no memory leaks)
- [ ] Document appears in Proposals Page
- [ ] Edit existing proposal
- [ ] Unsaved changes indicator
- [ ] Saved status indicator
- [ ] Authentication token refresh
- [ ] Network error handling
- [ ] Empty document save
- [ ] Large document save

## Troubleshooting

### Auto-save Not Working
- Check authentication token is valid
- Verify backend API is running
- Check network connectivity
- View console for error messages

### Document Not Appearing in Proposals
- Ensure save completed successfully
- Check proposal ID was stored
- Refresh proposals page
- Verify API endpoint is correct

### Version History Empty
- Versions stored in memory only
- Will reset when editor is closed
- Backend version storage coming soon

## Files Modified
- `frontend_flutter/lib/pages/creator/blank_document_editor_page.dart`
  - Added auto-save functionality
  - Added version control
  - Added backend integration
  - Added Save & Close button
  - Updated UI for save status

## Dependencies
- `dart:async` - Timer for debounced auto-save
- `dart:convert` - JSON serialization
- `api_service.dart` - Backend API calls
- `firebase_service.dart` - Authentication
- `auth_service.dart` - User profile

## Conclusion
The document editor now provides a robust, user-friendly experience with automatic saving, version control, and seamless integration with the proposals management system. Users never have to worry about losing work, can easily track changes through versions, and have their documents automatically available in the proposals page.

