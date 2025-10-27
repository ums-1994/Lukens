# Versioning & Comments - Current Status & Integration Plan

## 📊 Current Status

### ✅ Database Tables Exist

**PROPOSAL_VERSIONS Table:**
```sql
- id (uuid)
- proposal_id (uuid)  
- version_number (integer)
- content (jsonb)
- created_by (uuid)
- created_at (timestamp)
```

**DOCUMENT_COMMENTS Table:**
```sql
- id (integer)
- proposal_id (integer)
- comment_text (text)
- created_by (varchar)
- created_at (timestamp)
```

### ⚠️ Current Limitations

**❌ Versions ARE NOT Being Saved to Database**
- Versions are only stored in memory (`_versionHistory` list in widget state)
- When you navigate away or refresh, all version history is lost
- No API calls to save versions to the database

**❌ Comments ARE NOT Being Saved to Database**
- Comments are only stored in memory (`_comments` list in widget state)
- When you navigate away or refresh, all comments are lost
- Backend endpoints exist (`/api/comments/document/<proposal_id>`) but frontend doesn't call them

## 🔍 What's Happening Now

### Versions (Auto-versioning):
```dart
void _createVersion(String changeDescription) {
  final version = {
    'version_number': _currentVersionNumber,
    'timestamp': DateTime.now().toIso8601String(),
    'title': _titleController.text,
    'sections': _sections.map(...).toList(),
    'change_description': changeDescription,
    'author': _getCommenterName(),
  };
  
  setState(() {
    _versionHistory.add(version);  // ❌ Only in memory!
    _currentVersionNumber++;
  });
}
```

**No database save!** Versions are lost when you leave the page.

### Comments:
```dart
Future<void> _addComment() async {
  final newComment = {
    'id': DateTime.now().millisecondsSinceEpoch,
    'commenter_name': commenterName,
    'comment_text': commentText,
    // ... other fields
  };
  
  setState(() {
    _comments.insert(0, newComment);  // ❌ Only in memory!
  });
}
```

**No API call!** Comments are lost when you leave the page.

## ⚠️ Schema Mismatch Issue

The database tables have **UUID** fields but your proposals table uses **INTEGER** IDs:

```
proposals table: id (integer)
proposal_versions table: proposal_id (uuid)  ❌ Type mismatch!
document_comments table: proposal_id (integer)  ✅ Matches
```

This needs to be resolved for versions to work properly.

## 🛠️ What Needs to Be Done

### For Versions to Work:

1. **Fix Schema Mismatch**: 
   - Either change `proposal_versions.proposal_id` from UUID to INTEGER
   - Or change `proposals.id` from INTEGER to UUID (breaking change)

2. **Create Backend Endpoint**:
   ```python
   @app.post("/api/proposals/<int:proposal_id>/versions")
   def create_version(proposal_id):
       # Save version to database
   ```

3. **Update Frontend**:
   - Call API endpoint in `_createVersion()`
   - Load versions from database when opening document

### For Comments to Work:

1. **Backend Already Ready**: ✅
   - `POST /api/comments/document/<proposal_id>` exists
   - `GET /api/comments/proposal/<proposal_id>` exists

2. **Update Frontend**:
   - Call API in `_addComment()` to save to database
   - Load comments from database when opening document
   - Update/delete endpoints needed

## 🎯 Recommendation

### Option 1: Quick Fix (Comments Only)
**Time: ~30 minutes**
- Integrate comments with existing backend
- Versions stay in-memory (temporary)
- Users won't lose comments

### Option 2: Full Integration (Both)
**Time: ~2 hours**
- Fix schema mismatch for versions
- Create version endpoints
- Integrate both features with database
- Full persistence for both

### Option 3: Keep As-Is
**Time: 0 minutes**
- Versions and comments work within current session
- Data lost when navigating away
- Good for demo/testing

## 📝 Summary

| Feature | Table Exists | Backend Ready | Frontend Integrated | Persistent |
|---------|-------------|---------------|---------------------|-----------|
| **Versions** | ✅ Yes | ❌ No endpoints | ❌ Not calling DB | ❌ No - Memory only |
| **Comments** | ✅ Yes | ✅ Endpoints exist | ❌ Not calling endpoints | ❌ No - Memory only |
| **Proposals** | ✅ Yes | ✅ Fixed today | ✅ Integrated | ✅ Yes - Fully working |

## 🚀 Next Steps

**Would you like me to:**

1. **Integrate Comments with Database** (Quick win - 30 min)
   - Users can add comments that persist
   - Comments load when reopening document

2. **Fix and Integrate Versions** (Full solution - 2 hours)
   - Auto-versioning saves to database
   - Version history persists across sessions
   - Can restore old versions anytime

3. **Both** (Complete solution - 2-3 hours)
   - Full persistence for everything
   - Professional-grade document management

Let me know which option you'd prefer, and I'll implement it! 🎯

