# Client Management Database Schema

**Version:** 1.0  
**Last Updated:** November 5, 2025  
**Purpose:** Database structure for secure client onboarding and management system

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Database Architecture](#database-architecture)
3. [Table Definitions](#table-definitions)
4. [Relationships & ERD](#relationships--erd)
5. [SQL Creation Scripts](#sql-creation-scripts)
6. [Common Queries](#common-queries)
7. [API Endpoints (Future)](#api-endpoints-future)
8. [Security Considerations](#security-considerations)

---

## 🎯 Overview

The Client Management system replaces the Collaborations page and provides:
- **Secure client onboarding** via token-based invitation links
- **Comprehensive client data storage** (company info, project needs, contact details)
- **Client-to-proposal linking** for relationship tracking
- **Internal notes system** for team communication

### Key Features
- ✅ Token-based secure invitations (similar to collaboration system)
- ✅ Self-service client onboarding
- ✅ Automatic data validation and storage
- ✅ Role-based access (Creator & Approver can manage clients)
- ✅ Client proposal associations
- ✅ Internal notes (not visible to clients)

---

## 🏗️ Database Architecture

### Core Tables

| Table Name | Purpose | Dependencies |
|------------|---------|--------------|
| `client_onboarding_invitations` | Stores secure invitation links | `users` |
| `clients` | Stores complete client information | `users`, `client_onboarding_invitations` |
| `client_proposals` | Links clients to proposals | `clients`, `proposals`, `users` |
| `client_notes` | Internal notes about clients | `clients`, `users` |

### Data Flow

```
1. Creator/Approver → Generate Invitation → client_onboarding_invitations
2. Client → Clicks Link → Validates Token
3. Client → Fills Form → Data Submitted
4. System → Saves Data → clients table
5. System → Updates Invitation → status = 'completed'
6. Creator/Approver → Views Client → Client Management Page
7. Creator/Approver → Links to Proposal → client_proposals table
8. Creator/Approver → Adds Notes → client_notes table
```

---

## 📊 Table Definitions

### 1. `client_onboarding_invitations`

Stores secure invitation links sent to potential clients for onboarding.

#### Schema

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | SERIAL | PRIMARY KEY | Auto-incrementing ID |
| `access_token` | VARCHAR(500) | UNIQUE, NOT NULL | Secure token for link (URL-safe) |
| `invited_email` | VARCHAR(255) | - | Optional pre-filled email |
| `invited_by` | INTEGER | NOT NULL, FK → users(id) | User who sent invitation |
| `expected_company` | VARCHAR(255) | - | Optional expected company name |
| `status` | VARCHAR(50) | DEFAULT 'pending' | Current status of invitation |
| `invited_at` | TIMESTAMP | DEFAULT NOW() | When invitation was created |
| `completed_at` | TIMESTAMP | - | When client completed onboarding |
| `expires_at` | TIMESTAMP | NOT NULL | Expiration date (7-14 days) |
| `client_id` | INTEGER | FK → clients(id) | Links to created client record |

#### Status Values
- `pending` - Invitation sent, not yet opened
- `completed` - Client finished onboarding
- `expired` - Token expired (past expires_at)
- `cancelled` - Invitation cancelled by sender

#### Indexes
- `idx_client_onboard_token` - Fast token lookup
- `idx_client_onboard_status` - Filter by status
- `idx_client_onboard_invited_by` - Filter by sender
- `idx_client_onboard_expires` - Expiration checks

---

### 2. `clients`

Stores all client information collected during onboarding.

#### Schema

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | SERIAL | PRIMARY KEY | Auto-incrementing ID |
| **Basic Information** |
| `company_name` | VARCHAR(255) | NOT NULL | Client company name |
| `contact_person` | VARCHAR(255) | NOT NULL | Primary contact name |
| `email` | VARCHAR(255) | NOT NULL | Primary contact email |
| `phone` | VARCHAR(50) | - | Contact phone number |
| **Business Details** |
| `industry` | VARCHAR(100) | - | Industry/sector |
| `company_size` | VARCHAR(50) | - | Employee count range |
| `location` | VARCHAR(255) | - | Company location/address |
| `business_type` | VARCHAR(100) | - | Type of business |
| **Project Information** |
| `project_needs` | TEXT | - | Detailed project requirements |
| `budget_range` | VARCHAR(50) | - | Estimated budget |
| `timeline` | VARCHAR(100) | - | Desired timeline |
| `additional_info` | TEXT | - | Any extra information |
| **Status & Tracking** |
| `status` | VARCHAR(50) | DEFAULT 'active' | Client status |
| `onboarding_token` | VARCHAR(500) | FK → client_onboarding_invitations | Original invitation token |
| `created_by` | INTEGER | NOT NULL, FK → users(id) | User who invited client |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Record creation time |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | Last update time |

#### Status Values
- `active` - Active client
- `inactive` - Inactive/dormant
- `archived` - Archived client
- `prospect` - Potential client (not yet engaged)

#### Indexes
- `idx_clients_email` - Email lookups
- `idx_clients_company` - Company name searches
- `idx_clients_status` - Filter by status
- `idx_clients_created_by` - Filter by creator
- `idx_clients_created_at` - Sort by date (DESC)

---

### 3. `client_proposals` (Bonus)

Links clients to their associated proposals for relationship tracking.

#### Schema

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | SERIAL | PRIMARY KEY | Auto-incrementing ID |
| `client_id` | INTEGER | NOT NULL, FK → clients(id) | Client reference |
| `proposal_id` | INTEGER | NOT NULL, FK → proposals(id) | Proposal reference |
| `relationship_type` | VARCHAR(50) | DEFAULT 'primary' | Type of relationship |
| `linked_at` | TIMESTAMP | DEFAULT NOW() | When link was created |
| `linked_by` | INTEGER | NOT NULL, FK → users(id) | User who created link |

#### Relationship Types
- `primary` - Primary client for proposal
- `billing` - Billing contact
- `technical` - Technical contact
- `stakeholder` - Additional stakeholder

#### Constraints
- `UNIQUE(client_id, proposal_id)` - Prevent duplicate links

#### Indexes
- `idx_client_proposals_client` - Find proposals by client
- `idx_client_proposals_proposal` - Find clients by proposal

---

### 4. `client_notes` (Bonus)

Internal notes about clients (not visible to clients).

#### Schema

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | SERIAL | PRIMARY KEY | Auto-incrementing ID |
| `client_id` | INTEGER | NOT NULL, FK → clients(id) | Client reference |
| `note_text` | TEXT | NOT NULL | Note content |
| `created_by` | INTEGER | NOT NULL, FK → users(id) | Note author |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Creation time |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | Last update time |

#### Indexes
- `idx_client_notes_client` - Find notes by client
- `idx_client_notes_created` - Sort by date (DESC)

---

## 🔗 Relationships & ERD

```
┌─────────────────────────────────────────────────────────────┐
│                        USERS TABLE                          │
│                      (existing table)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ invited_by
                              ▼
┌─────────────────────────────────────────────────────────────┐
│             CLIENT_ONBOARDING_INVITATIONS                   │
│  - id                                                       │
│  - access_token (UNIQUE)                                    │
│  - invited_email                                            │
│  - invited_by → users(id)                                   │
│  - status (pending/completed/expired)                       │
│  - expires_at                                               │
│  - client_id → clients(id)                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ client_id (after completion)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      CLIENTS TABLE                          │
│  - id                                                       │
│  - company_name, contact_person, email, phone               │
│  - industry, company_size, location                         │
│  - project_needs, budget_range, timeline                    │
│  - status (active/inactive/archived)                        │
│  - created_by → users(id)                                   │
│  - onboarding_token → client_onboarding_invitations         │
└─────────────────────────────────────────────────────────────┘
                    │                     │
        ┌───────────┘                     └───────────┐
        │                                             │
        ▼                                             ▼
┌──────────────────────┐                  ┌──────────────────────┐
│  CLIENT_PROPOSALS    │                  │   CLIENT_NOTES       │
│  - client_id         │                  │   - client_id        │
│  - proposal_id       │                  │   - note_text        │
│  - relationship_type │                  │   - created_by       │
│  - linked_by         │                  │   - created_at       │
└──────────────────────┘                  └──────────────────────┘
        │
        └──────────────────────┐
                               ▼
                    ┌─────────────────────┐
                    │  PROPOSALS TABLE    │
                    │  (existing table)   │
                    └─────────────────────┘
```

### Foreign Key Relationships

```sql
-- client_onboarding_invitations
FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE CASCADE
FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL

-- clients
FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
FOREIGN KEY (onboarding_token) REFERENCES client_onboarding_invitations(access_token) ON DELETE SET NULL

-- client_proposals
FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE
FOREIGN KEY (linked_by) REFERENCES users(id) ON DELETE CASCADE

-- client_notes
FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
```

---

## 🛠️ SQL Creation Scripts

### Full Database Setup

```sql
-- ============================================================
-- CLIENT ONBOARDING INVITATIONS TABLE
-- ============================================================
-- Stores secure link invitations sent to potential clients
-- Similar pattern to collaboration_invitations

CREATE TABLE client_onboarding_invitations (
    id SERIAL PRIMARY KEY,
    access_token VARCHAR(500) UNIQUE NOT NULL,
    invited_email VARCHAR(255),
    invited_by INTEGER NOT NULL,
    expected_company VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    client_id INTEGER,
    FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
);

-- Create indexes for faster queries
CREATE INDEX idx_client_onboard_token ON client_onboarding_invitations(access_token);
CREATE INDEX idx_client_onboard_status ON client_onboarding_invitations(status);
CREATE INDEX idx_client_onboard_invited_by ON client_onboarding_invitations(invited_by);
CREATE INDEX idx_client_onboard_expires ON client_onboarding_invitations(expires_at);

-- Add comment for documentation
COMMENT ON TABLE client_onboarding_invitations IS 'Stores secure invitation links for client onboarding';


-- ============================================================
-- CLIENTS TABLE
-- ============================================================
-- Stores all client information after they complete onboarding

CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    
    -- Basic Information
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    
    -- Business Details
    industry VARCHAR(100),
    company_size VARCHAR(50),
    location VARCHAR(255),
    business_type VARCHAR(100),
    
    -- Project Information
    project_needs TEXT,
    budget_range VARCHAR(50),
    timeline VARCHAR(100),
    additional_info TEXT,
    
    -- Status & Tracking
    status VARCHAR(50) DEFAULT 'active',
    onboarding_token VARCHAR(500),
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Keys
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (onboarding_token) REFERENCES client_onboarding_invitations(access_token) ON DELETE SET NULL
);

-- Create indexes for faster queries
CREATE INDEX idx_clients_email ON clients(email);
CREATE INDEX idx_clients_company ON clients(company_name);
CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_clients_created_by ON clients(created_by);
CREATE INDEX idx_clients_created_at ON clients(created_at DESC);

-- Add comment for documentation
COMMENT ON TABLE clients IS 'Stores all client information from onboarding';


-- ============================================================
-- CLIENT PROPOSALS LINK TABLE (BONUS - for linking clients to proposals)
-- ============================================================
-- Links clients to their proposals

CREATE TABLE client_proposals (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    proposal_id INTEGER NOT NULL,
    relationship_type VARCHAR(50) DEFAULT 'primary',
    linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    linked_by INTEGER NOT NULL,
    
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (linked_by) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Ensure unique client-proposal combinations
    UNIQUE(client_id, proposal_id)
);

-- Create indexes
CREATE INDEX idx_client_proposals_client ON client_proposals(client_id);
CREATE INDEX idx_client_proposals_proposal ON client_proposals(proposal_id);

-- Add comment
COMMENT ON TABLE client_proposals IS 'Links clients to their associated proposals';


-- ============================================================
-- CLIENT NOTES TABLE (BONUS - for internal notes about clients)
-- ============================================================
-- Internal notes that clients cannot see

CREATE TABLE client_notes (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    note_text TEXT NOT NULL,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_client_notes_client ON client_notes(client_id);
CREATE INDEX idx_client_notes_created ON client_notes(created_at DESC);

-- Add comment
COMMENT ON TABLE client_notes IS 'Internal notes about clients (not visible to clients)';
```

### Verification Queries

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('client_onboarding_invitations', 'clients', 'client_proposals', 'client_notes');

-- Check table structures
\d client_onboarding_invitations
\d clients
\d client_proposals
\d client_notes

-- Count records
SELECT 'client_onboarding_invitations' as table_name, COUNT(*) as count FROM client_onboarding_invitations
UNION ALL
SELECT 'clients', COUNT(*) FROM clients
UNION ALL
SELECT 'client_proposals', COUNT(*) FROM client_proposals
UNION ALL
SELECT 'client_notes', COUNT(*) FROM client_notes;
```

---

## 🔍 Common Queries

### 1. Get All Active Clients

```sql
SELECT 
    c.id,
    c.company_name,
    c.contact_person,
    c.email,
    c.phone,
    c.industry,
    c.status,
    c.created_at,
    u.full_name as created_by_name,
    u.email as created_by_email
FROM clients c
JOIN users u ON c.created_by = u.id
WHERE c.status = 'active'
ORDER BY c.created_at DESC;
```

### 2. Get Client with Onboarding Details

```sql
SELECT 
    c.*,
    coi.access_token,
    coi.invited_at,
    coi.completed_at,
    coi.expires_at,
    u.full_name as invited_by_name
FROM clients c
LEFT JOIN client_onboarding_invitations coi ON c.onboarding_token = coi.access_token
LEFT JOIN users u ON coi.invited_by = u.id
WHERE c.id = $1;
```

### 3. Get Pending Invitations (Not Expired)

```sql
SELECT 
    coi.*,
    u.full_name as invited_by_name,
    u.email as invited_by_email
FROM client_onboarding_invitations coi
JOIN users u ON coi.invited_by = u.id
WHERE coi.status = 'pending'
AND coi.expires_at > CURRENT_TIMESTAMP
ORDER BY coi.invited_at DESC;
```

### 4. Get Client with All Related Data

```sql
SELECT 
    c.*,
    -- Count of proposals
    COUNT(DISTINCT cp.proposal_id) as proposal_count,
    -- Count of notes
    COUNT(DISTINCT cn.id) as note_count,
    -- Invited by
    u.full_name as created_by_name
FROM clients c
LEFT JOIN client_proposals cp ON c.id = cp.client_id
LEFT JOIN client_notes cn ON c.id = cn.client_id
LEFT JOIN users u ON c.created_by = u.id
WHERE c.id = $1
GROUP BY c.id, u.full_name;
```

### 5. Get Client Proposals with Details

```sql
SELECT 
    cp.*,
    c.company_name,
    c.contact_person,
    p.title as proposal_title,
    p.status as proposal_status,
    p.created_at as proposal_created_at,
    u.full_name as linked_by_name
FROM client_proposals cp
JOIN clients c ON cp.client_id = c.id
JOIN proposals p ON cp.proposal_id = p.id
JOIN users u ON cp.linked_by = u.id
WHERE cp.client_id = $1
ORDER BY cp.linked_at DESC;
```

### 6. Get Client Notes with Authors

```sql
SELECT 
    cn.*,
    u.full_name as author_name,
    u.email as author_email
FROM client_notes cn
JOIN users u ON cn.created_by = u.id
WHERE cn.client_id = $1
ORDER BY cn.created_at DESC;
```

### 7. Search Clients by Company Name or Contact

```sql
SELECT 
    c.*,
    u.full_name as created_by_name
FROM clients c
JOIN users u ON c.created_by = u.id
WHERE 
    c.company_name ILIKE $1
    OR c.contact_person ILIKE $1
    OR c.email ILIKE $1
ORDER BY c.created_at DESC
LIMIT 50;
```

### 8. Get Expired Invitations (Auto-cleanup)

```sql
-- Find expired invitations
SELECT * FROM client_onboarding_invitations
WHERE status = 'pending'
AND expires_at < CURRENT_TIMESTAMP;

-- Mark as expired
UPDATE client_onboarding_invitations
SET status = 'expired'
WHERE status = 'pending'
AND expires_at < CURRENT_TIMESTAMP;
```

### 9. Get Client Statistics by Creator

```sql
SELECT 
    u.id,
    u.full_name,
    u.email,
    COUNT(c.id) as total_clients,
    COUNT(CASE WHEN c.status = 'active' THEN 1 END) as active_clients,
    COUNT(CASE WHEN c.created_at >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) as recent_clients
FROM users u
LEFT JOIN clients c ON u.id = c.created_by
GROUP BY u.id, u.full_name, u.email
ORDER BY total_clients DESC;
```

### 10. Get Dashboard Summary

```sql
SELECT 
    (SELECT COUNT(*) FROM clients WHERE status = 'active') as active_clients,
    (SELECT COUNT(*) FROM clients WHERE created_at >= CURRENT_DATE - INTERVAL '30 days') as new_clients_this_month,
    (SELECT COUNT(*) FROM client_onboarding_invitations WHERE status = 'pending' AND expires_at > CURRENT_TIMESTAMP) as pending_invitations,
    (SELECT COUNT(*) FROM client_onboarding_invitations WHERE status = 'completed' AND completed_at >= CURRENT_DATE - INTERVAL '30 days') as completed_this_month;
```

---

## 🔌 API Endpoints (Future Implementation)

### Client Invitation Endpoints

#### `POST /api/clients/invite`
**Auth:** Required (Creator/Approver)  
**Purpose:** Generate secure invitation link for client onboarding

**Request Body:**
```json
{
  "invited_email": "client@company.com",
  "expected_company": "Acme Corp",
  "expires_in_days": 7
}
```

**Response:**
```json
{
  "success": true,
  "invitation": {
    "id": 123,
    "access_token": "secure_token_here",
    "invitation_url": "https://app.com/#/client-onboard?token=secure_token_here",
    "invited_email": "client@company.com",
    "expires_at": "2025-11-12T10:30:00Z",
    "status": "pending"
  }
}
```

---

#### `GET /api/clients/onboard?token={token}`
**Auth:** Not Required (Public endpoint)  
**Purpose:** Validate invitation token and get onboarding form

**Response:**
```json
{
  "success": true,
  "invitation": {
    "id": 123,
    "invited_email": "client@company.com",
    "expected_company": "Acme Corp",
    "expires_at": "2025-11-12T10:30:00Z",
    "invited_by": {
      "full_name": "John Doe",
      "email": "john@company.com"
    }
  }
}
```

---

#### `POST /api/clients/onboard`
**Auth:** Not Required (Token validation)  
**Purpose:** Submit client onboarding information

**Request Body:**
```json
{
  "token": "secure_token_here",
  "company_name": "Acme Corporation",
  "contact_person": "Jane Smith",
  "email": "jane@acme.com",
  "phone": "+1-555-0123",
  "industry": "Technology",
  "company_size": "50-100",
  "location": "New York, NY",
  "business_type": "SaaS",
  "project_needs": "Need new proposal system...",
  "budget_range": "$50k-$100k",
  "timeline": "3-6 months",
  "additional_info": "Looking for AI integration"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Onboarding completed successfully",
  "client": {
    "id": 456,
    "company_name": "Acme Corporation",
    "contact_person": "Jane Smith",
    "email": "jane@acme.com",
    "status": "active",
    "created_at": "2025-11-05T14:30:00Z"
  }
}
```

---

### Client Management Endpoints

#### `GET /api/clients`
**Auth:** Required (Creator/Approver)  
**Purpose:** List all clients with filtering and pagination

**Query Parameters:**
- `status` - Filter by status (active/inactive/archived)
- `search` - Search by company name, contact, or email
- `created_by` - Filter by creator user ID
- `page` - Page number (default: 1)
- `limit` - Items per page (default: 50)

**Response:**
```json
{
  "success": true,
  "clients": [
    {
      "id": 456,
      "company_name": "Acme Corporation",
      "contact_person": "Jane Smith",
      "email": "jane@acme.com",
      "phone": "+1-555-0123",
      "industry": "Technology",
      "status": "active",
      "created_at": "2025-11-05T14:30:00Z",
      "proposal_count": 3,
      "note_count": 5,
      "created_by": {
        "id": 1,
        "full_name": "John Doe"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 150,
    "pages": 3
  }
}
```

---

#### `GET /api/clients/{client_id}`
**Auth:** Required (Creator/Approver)  
**Purpose:** Get detailed client information

**Response:**
```json
{
  "success": true,
  "client": {
    "id": 456,
    "company_name": "Acme Corporation",
    "contact_person": "Jane Smith",
    "email": "jane@acme.com",
    "phone": "+1-555-0123",
    "industry": "Technology",
    "company_size": "50-100",
    "location": "New York, NY",
    "business_type": "SaaS",
    "project_needs": "Need new proposal system...",
    "budget_range": "$50k-$100k",
    "timeline": "3-6 months",
    "additional_info": "Looking for AI integration",
    "status": "active",
    "created_at": "2025-11-05T14:30:00Z",
    "updated_at": "2025-11-05T14:30:00Z",
    "created_by": {
      "id": 1,
      "full_name": "John Doe",
      "email": "john@company.com"
    },
    "onboarding": {
      "invited_at": "2025-11-01T10:00:00Z",
      "completed_at": "2025-11-05T14:30:00Z"
    },
    "proposals": [
      {
        "id": 789,
        "title": "Website Redesign",
        "status": "approved",
        "relationship_type": "primary"
      }
    ],
    "notes": [
      {
        "id": 1,
        "note_text": "Client is very responsive",
        "created_by": "John Doe",
        "created_at": "2025-11-05T15:00:00Z"
      }
    ]
  }
}
```

---

#### `PUT /api/clients/{client_id}`
**Auth:** Required (Creator/Approver)  
**Purpose:** Update client information

**Request Body:** (all fields optional)
```json
{
  "company_name": "Acme Corp Updated",
  "contact_person": "Jane Smith",
  "phone": "+1-555-9999",
  "status": "active"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Client updated successfully",
  "client": { /* updated client data */ }
}
```

---

#### `DELETE /api/clients/{client_id}`
**Auth:** Required (Admin only)  
**Purpose:** Delete client (use with caution)

**Response:**
```json
{
  "success": true,
  "message": "Client deleted successfully"
}
```

---

### Client-Proposal Linking Endpoints

#### `POST /api/clients/{client_id}/proposals`
**Auth:** Required (Creator/Approver)  
**Purpose:** Link a proposal to a client

**Request Body:**
```json
{
  "proposal_id": 789,
  "relationship_type": "primary"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Proposal linked to client successfully",
  "link": {
    "id": 1,
    "client_id": 456,
    "proposal_id": 789,
    "relationship_type": "primary",
    "linked_at": "2025-11-05T16:00:00Z"
  }
}
```

---

#### `GET /api/clients/{client_id}/proposals`
**Auth:** Required (Creator/Approver)  
**Purpose:** Get all proposals linked to a client

**Response:**
```json
{
  "success": true,
  "proposals": [
    {
      "id": 789,
      "title": "Website Redesign",
      "status": "approved",
      "relationship_type": "primary",
      "linked_at": "2025-11-05T16:00:00Z",
      "linked_by": {
        "full_name": "John Doe"
      }
    }
  ]
}
```

---

#### `DELETE /api/clients/{client_id}/proposals/{proposal_id}`
**Auth:** Required (Creator/Approver)  
**Purpose:** Unlink a proposal from a client

**Response:**
```json
{
  "success": true,
  "message": "Proposal unlinked from client successfully"
}
```

---

### Client Notes Endpoints

#### `POST /api/clients/{client_id}/notes`
**Auth:** Required (Creator/Approver)  
**Purpose:** Add internal note about a client

**Request Body:**
```json
{
  "note_text": "Client prefers email communication"
}
```

**Response:**
```json
{
  "success": true,
  "note": {
    "id": 1,
    "client_id": 456,
    "note_text": "Client prefers email communication",
    "created_by": {
      "id": 1,
      "full_name": "John Doe"
    },
    "created_at": "2025-11-05T17:00:00Z"
  }
}
```

---

#### `GET /api/clients/{client_id}/notes`
**Auth:** Required (Creator/Approver)  
**Purpose:** Get all notes for a client

**Response:**
```json
{
  "success": true,
  "notes": [
    {
      "id": 1,
      "note_text": "Client prefers email communication",
      "created_by": {
        "id": 1,
        "full_name": "John Doe",
        "email": "john@company.com"
      },
      "created_at": "2025-11-05T17:00:00Z"
    }
  ]
}
```

---

#### `PUT /api/clients/{client_id}/notes/{note_id}`
**Auth:** Required (Note author only)  
**Purpose:** Update a note

**Request Body:**
```json
{
  "note_text": "Updated note content"
}
```

---

#### `DELETE /api/clients/{client_id}/notes/{note_id}`
**Auth:** Required (Note author or Admin)  
**Purpose:** Delete a note

---

### Dashboard/Statistics Endpoints

#### `GET /api/clients/stats`
**Auth:** Required (Creator/Approver)  
**Purpose:** Get client management statistics

**Response:**
```json
{
  "success": true,
  "stats": {
    "total_clients": 150,
    "active_clients": 120,
    "inactive_clients": 25,
    "archived_clients": 5,
    "new_this_month": 12,
    "pending_invitations": 5,
    "completed_invitations_this_month": 8,
    "clients_by_industry": {
      "Technology": 50,
      "Healthcare": 30,
      "Finance": 25,
      "Retail": 20,
      "Other": 25
    },
    "clients_by_budget": {
      "Under $25k": 30,
      "$25k-$50k": 40,
      "$50k-$100k": 50,
      "Over $100k": 30
    }
  }
}
```

---

## 🔒 Security Considerations

### Token Security
- **Token Generation:** Use `secrets.token_urlsafe(32)` for cryptographically secure tokens
- **Token Storage:** Store hashed tokens if extra security needed (optional)
- **Token Expiration:** Default 7-14 days, enforce strictly
- **Single Use:** Mark token as 'completed' after first use (prevent replay attacks)

### Access Control
- **Invitations:** Only Creator/Approver can generate
- **Client Data:** Only Creator/Approver can view
- **Notes:** Internal only, never exposed to clients
- **Onboarding:** Public endpoint but token-validated

### Data Validation
- **Email Format:** Validate email addresses
- **Phone Format:** Basic format validation
- **Required Fields:** Enforce on submission
- **XSS Protection:** Sanitize all text inputs
- **SQL Injection:** Use parameterized queries

### GDPR/Privacy
- **Data Retention:** Define retention policy
- **Client Consent:** Store consent timestamp
- **Data Export:** Allow clients to request their data
- **Data Deletion:** Implement right to be forgotten

### Rate Limiting
- **Invitation Creation:** 10 per hour per user
- **Onboarding Submission:** 3 attempts per token
- **API Calls:** 100 per minute per user

---

## 🚀 Implementation Checklist

### Database Setup
- [ ] Run SQL creation scripts
- [ ] Verify tables created successfully
- [ ] Test foreign key relationships
- [ ] Add sample data for testing

### Backend API
- [ ] Implement invitation generation endpoint
- [ ] Implement token validation endpoint
- [ ] Implement onboarding submission endpoint
- [ ] Implement client CRUD endpoints
- [ ] Implement proposal linking endpoints
- [ ] Implement notes endpoints
- [ ] Add email notifications for invitations
- [ ] Add input validation and sanitization
- [ ] Add rate limiting
- [ ] Add error handling

### Frontend (Flutter)
- [ ] Replace `collaboration_page.dart` with Client Management page
- [ ] Create client list view with search/filter
- [ ] Create client detail view
- [ ] Create "Invite Client" button and dialog
- [ ] Create public onboarding form (no auth)
- [ ] Add proposal linking UI
- [ ] Add internal notes UI
- [ ] Add client statistics dashboard
- [ ] Add export functionality (CSV/Excel)
- [ ] Test all user flows

### Testing
- [ ] Test invitation generation
- [ ] Test token validation
- [ ] Test expired tokens
- [ ] Test onboarding submission
- [ ] Test client CRUD operations
- [ ] Test proposal linking
- [ ] Test notes system
- [ ] Test permissions (Creator vs Approver)
- [ ] Test email delivery
- [ ] Load testing (100+ clients)

### Documentation
- [ ] API documentation (Postman/Swagger)
- [ ] User guide for inviting clients
- [ ] User guide for managing clients
- [ ] Admin guide for troubleshooting
- [ ] Database backup procedures

---

## 📝 Notes

### Design Decisions
1. **Separate Invitations Table:** Allows tracking invitation history even after client onboarding
2. **Flexible Client Fields:** Most fields optional to reduce onboarding friction
3. **Status Field:** Allows archiving without deletion (better for auditing)
4. **Notes System:** Internal communication without cluttering client record
5. **Proposal Linking:** Flexible many-to-many relationship with relationship types

### Future Enhancements
- [ ] Client portal (clients can log in and view their proposals)
- [ ] Document sharing with clients
- [ ] Client activity timeline
- [ ] Automated follow-up reminders
- [ ] Client segmentation and tagging
- [ ] Advanced analytics (conversion rates, response times)
- [ ] Integration with CRM systems
- [ ] Multi-language support for onboarding form

---

## 🆘 Support & Troubleshooting

### Common Issues

**Issue:** Token not found  
**Solution:** Check token expiration, verify token in URL

**Issue:** Foreign key violation  
**Solution:** Ensure `users` and `proposals` tables exist first

**Issue:** Slow queries  
**Solution:** Verify indexes are created, use EXPLAIN ANALYZE

**Issue:** Duplicate client emails  
**Solution:** Add unique constraint on email if needed (currently allows duplicates for multiple contacts)

---

## 📚 References

- Existing collaboration system: `backend/app.py` → `/api/collaborate` endpoints
- User authentication: `backend/app.py` → `check_auth()` decorator
- Email service: `backend/app.py` → `send_email()` function
- Frontend navigation: `frontend_flutter/lib/main.dart` → routes

---

**Document Status:** ✅ Ready for Implementation  
**Next Steps:** Run SQL scripts → Implement backend endpoints → Build frontend UI  
**Estimated Time:** 8-12 hours full implementation

---

*This document will be updated as the system evolves. Last updated: November 5, 2025*







