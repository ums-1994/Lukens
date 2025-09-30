# 🐘 PostgreSQL Autosave + Version History Implementation

This document describes the **PostgreSQL-backed** implementation of Draft Autosave, Version History, and Change Tracking functionality for the Proposal Builder app.

## 🎯 Overview

The system has been upgraded from JSON file storage to **PostgreSQL** for better performance, reliability, and scalability. All version history is now stored in a proper relational database with full ACID compliance.

## 🗄️ Database Schema

### Proposal Versions Table
```sql
CREATE TABLE proposal_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id UUID NOT NULL,
  version_number INT NOT NULL,
  content JSONB NOT NULL,
  created_by UUID,
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- Foreign key constraints
  CONSTRAINT fk_proposal_versions_proposal_id 
    FOREIGN KEY (proposal_id) 
    REFERENCES proposals(id) ON DELETE CASCADE,
    
  CONSTRAINT fk_proposal_versions_created_by 
    FOREIGN KEY (created_by) 
    REFERENCES users(id) ON DELETE SET NULL
);
```

### Indexes for Performance
```sql
-- Index for faster lookups by proposal
CREATE INDEX idx_proposal_versions_proposal_id 
  ON proposal_versions(proposal_id);

-- Index for chronological ordering
CREATE INDEX idx_proposal_versions_created_at 
  ON proposal_versions(created_at DESC);

-- Composite index for version ordering
CREATE INDEX idx_proposal_versions_version_number 
  ON proposal_versions(proposal_id, version_number);
```

## 🚀 Quick Setup

### 1. Environment Configuration
Create a `.env` file in the backend directory:
```env
# PostgreSQL Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=postgres
DB_PASSWORD=Password123
```

### 2. Run Setup Script
```bash
cd backend
python setup_postgresql.py
```

This script will:
- ✅ Check environment variables
- ✅ Test database connection
- ✅ Run database migrations
- ✅ Verify table structure
- ✅ Confirm setup success

### 3. Start the Application
```bash
# Backend
cd backend
python app.py

# Frontend
cd frontend_flutter
flutter run
```

## 🔧 Backend Implementation

### New Service Layer
**File:** `backend/proposal_versions_service.py`

The `ProposalVersionsService` class provides a clean interface for all version operations:

```python
class ProposalVersionsService:
    def create_version(proposal_id, content, created_by) -> Dict
    def get_versions(proposal_id) -> List[Dict]
    def get_version(proposal_id, version_id) -> Optional[Dict]
    def delete_version(proposal_id, version_id) -> bool
    def get_version_diff(proposal_id, from_version_id, to_version_id) -> Dict
    def get_latest_version(proposal_id) -> Optional[Dict]
```

### Updated API Endpoints

#### 1. Autosave with PostgreSQL
```http
POST /proposals/{id}/autosave
Content-Type: application/json

{
  "sections": {...},
  "version": "draft",
  "auto_saved": true,
  "timestamp": "2025-01-27T10:45:00Z",
  "user_id": "user-123"
}
```

**Response:**
```json
{
  "message": "Autosaved",
  "version_id": "uuid-here",
  "saved_at": "2025-01-27T10:45:00Z"
}
```

#### 2. Get All Versions
```http
GET /proposals/{id}/versions
```

**Response:**
```json
{
  "versions": [
    {
      "id": "uuid-1",
      "proposal_id": "proposal-uuid",
      "version_number": 3,
      "content": {...},
      "created_by": "user-123",
      "created_at": "2025-01-27T10:45:00Z"
    }
  ]
}
```

#### 3. Version Diff
```http
GET /proposals/{id}/versions/diff?from=uuid1&to=uuid2
```

**Response:**
```json
{
  "added": ["Added section 'Risks'"],
  "modified": ["Updated 'Executive Summary'"],
  "removed": ["Removed 'Case Study A'"],
  "from_version": "Version 2",
  "to_version": "Version 3"
}
```

## 📱 Frontend Integration

### Updated Services
The Flutter services have been updated to work seamlessly with the PostgreSQL backend:

1. **AutoDraftService** - Unchanged, works with new autosave endpoint
2. **VersioningService** - Updated to handle PostgreSQL response format
3. **AutoSaveIndicator** - Unchanged, provides same visual feedback

### Key Changes
- **Backward compatible** - Existing Flutter code works without changes
- **Enhanced error handling** - Better error messages from PostgreSQL
- **Improved performance** - Faster queries with proper indexing
- **Data integrity** - ACID compliance ensures data consistency

## 🎨 Features

### ✅ Autosave Functionality
- **30-second periodic saves** - Automatic background saving
- **2-second debounced saves** - Save when user stops typing
- **Visual indicators** - Real-time status feedback
- **Error handling** - Graceful failure and retry logic

### ✅ Version History
- **Automatic versioning** - Every autosave creates a version
- **Sequential numbering** - Clear version progression
- **Metadata tracking** - User, timestamp, and content
- **Efficient storage** - JSONB for flexible content storage

### ✅ Change Tracking
- **Server-side diffs** - Efficient comparison logic
- **Visual diff display** - Color-coded changes
- **Version comparison** - Compare any two versions
- **Restore functionality** - Revert to any previous version

## 🔍 Performance Optimizations

### Database Level
- **Proper indexing** - Fast lookups by proposal and timestamp
- **JSONB storage** - Efficient JSON storage and querying
- **Connection pooling** - Reuse database connections
- **Prepared statements** - SQL injection protection

### Application Level
- **Debounced saves** - Prevent excessive API calls
- **Change detection** - Only save when content changes
- **Background processing** - Non-blocking autosave
- **Error recovery** - Automatic retry on failures

## 🧪 Testing

### Manual Testing
1. **Start the demo:** Navigate to "Autosave Demo" in the app
2. **Edit content:** Make changes to any field
3. **Watch indicators:** Observe the autosave status
4. **Check history:** View version history page
5. **Compare versions:** Use the diff functionality
6. **Restore versions:** Test the restore feature

### Database Verification
```sql
-- Check if versions are being created
SELECT COUNT(*) FROM proposal_versions;

-- View recent versions
SELECT id, proposal_id, version_number, created_at 
FROM proposal_versions 
ORDER BY created_at DESC 
LIMIT 10;

-- Check version content
SELECT content FROM proposal_versions 
WHERE proposal_id = 'your-proposal-id' 
ORDER BY version_number DESC;
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```
❌ Database connection failed: connection to server at "localhost" (127.0.0.1), port 5432 failed
```
**Solution:** Ensure PostgreSQL is running and accessible

#### 2. Table Not Found
```
❌ proposal_versions table not found
```
**Solution:** Run the migration script: `python setup_postgresql.py`

#### 3. Permission Denied
```
❌ permission denied for table proposal_versions
```
**Solution:** Check database user permissions

#### 4. Migration Failed
```
❌ Migration failed: relation "proposals" does not exist
```
**Solution:** Ensure the main proposals table exists first

### Debug Mode
Enable debug logging by setting:
```env
FLASK_DEBUG=1
```

## 📊 Monitoring

### Database Metrics
Monitor these key metrics:
- **Version creation rate** - How often autosave triggers
- **Storage growth** - Monitor JSONB content size
- **Query performance** - Check slow query log
- **Connection usage** - Monitor connection pool

### Application Metrics
- **Autosave success rate** - Track failed saves
- **User activity** - Monitor editing patterns
- **Version usage** - Track restore frequency
- **Error rates** - Monitor API failures

## 🚀 Production Deployment

### Environment Variables
```env
# Production PostgreSQL Configuration
DB_HOST=your-postgres-host
DB_PORT=5432
DB_NAME=proposal_sow_builder_prod
DB_USER=proposal_app_user
DB_PASSWORD=secure-password

# Optional: Connection pooling
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20
```

### Database Maintenance
```sql
-- Regular cleanup of old versions (optional)
DELETE FROM proposal_versions 
WHERE created_at < NOW() - INTERVAL '90 days'
AND proposal_id IN (
  SELECT id FROM proposals WHERE status = 'Archived'
);

-- Analyze table for query optimization
ANALYZE proposal_versions;

-- Vacuum to reclaim space
VACUUM ANALYZE proposal_versions;
```

## 🔮 Future Enhancements

### Planned Features
1. **Version branching** - Create experimental branches
2. **Collaborative editing** - Real-time multi-user editing
3. **Advanced diffs** - Side-by-side comparison view
4. **Version comments** - Add notes to versions
5. **Bulk operations** - Mass version management

### Performance Improvements
1. **Read replicas** - Distribute read load
2. **Caching layer** - Redis for frequent queries
3. **Compression** - Compress old version content
4. **Partitioning** - Partition by date for large datasets

## 📋 Migration from JSON Storage

If migrating from the previous JSON-based system:

1. **Export existing data** from JSON files
2. **Transform data** to PostgreSQL format
3. **Run migration script** to create tables
4. **Import data** using the new service
5. **Verify data integrity** with test queries
6. **Update application** to use PostgreSQL endpoints

## 🎉 Conclusion

The PostgreSQL implementation provides:
- **Better performance** with proper indexing
- **Data integrity** with ACID compliance
- **Scalability** for growing datasets
- **Reliability** with transaction support
- **Maintainability** with clean service layer

The system is production-ready and provides a robust foundation for the Proposal Builder's autosave and versioning features.
