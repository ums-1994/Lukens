# 🔄 Role Switching System

## 🎯 Overview

A comprehensive role-based access system that allows users to switch between **Creator** and **Approver (CEO)** roles seamlessly within the application.

> **Future**: The approver functionality will eventually be a separate standalone application.

## ✨ Features

### Available Roles

| Role | Icon | Description | Access |
|------|------|-------------|--------|
| **Creator** | ✍️ | Create and manage proposals | • Dashboard<br>• Proposals<br>• Content Library<br>• Collaboration |
| **Approver (CEO)** | ✅ | Review and approve proposals | • Approval Queue<br>• Approval Metrics<br>• Approval History |
| **Admin** | 👑 | System administration | • All features<br>• Settings<br>• Analytics |

### Role Switcher UI

#### Compact Version (Header)
- Appears in the top-right of dashboards
- Shows current role icon + dropdown
- Quick switching without dialogs
- Persists selection across sessions

#### Full Version (Future)
- Detailed role cards with descriptions
- Permission previews
- Activity summaries per role

## 🚀 How to Use

### Switching Roles

1. **Locate the Role Switcher**
   - Top-right corner of any dashboard
   - Next to the refresh button
   - Shows your current role icon (✍️ or ✅)

2. **Click to Open Menu**
   ```
   ┌──────────────────────┐
   │ ✍️ Creator     ✓     │ ← Currently selected
   │ ✅ Approver (CEO)    │
   └──────────────────────┘
   ```

3. **Select New Role**
   - Click the role you want to switch to
   - Automatic navigation to appropriate dashboard
   - Toast confirmation appears

### Role-Specific Dashboards

#### Creator Mode (✍️)
- **Dashboard**: `/dashboard`
- **Features**:
  - Create new proposals
  - Edit existing proposals
  - View proposal statistics
  - Manage collaborations
  - Access content library

#### Approver Mode (✅)
- **Dashboard**: `/approver_dashboard`
- **Features**:
  - View pending approvals
  - Approve/reject proposals
  - View approval metrics
  - Access approval history
  - Quick actions on proposals

## 🔧 Technical Implementation

### Architecture

```
RoleService (ChangeNotifier)
├── Current Role State
├── Available Roles
├── Role Switching Logic
└── Permission Checking

MultiProvider
├── AppState
└── RoleService ⭐ NEW
```

### Key Files

#### 1. `services/role_service.dart`
**Purpose**: Core role management service

**Key Methods**:
```dart
class RoleService extends ChangeNotifier {
  UserRole _currentRole = UserRole.creator;
  
  // Get current role
  UserRole get currentRole => _currentRole;
  String get currentRoleName => _getRoleName(_currentRole);
  
  // Switch roles
  Future<void> switchRole(UserRole newRole);
  
  // Load persisted role
  Future<void> loadSavedRole();
  
  // Permission checks
  bool canCreateProposals();
  bool canApproveProposals();
  bool canAccessAdmin();
}
```

**State Management**:
- Uses `ChangeNotifier` for reactive updates
- Persists to `SharedPreferences`
- Broadcasts changes to all listeners

#### 2. `widgets/role_switcher.dart`
**Purpose**: UI components for role switching

**Components**:
```dart
// Full version with descriptions
class RoleSwitcher extends StatelessWidget

// Compact version for headers
class CompactRoleSwitcher extends StatelessWidget
```

**Features**:
- `PopupMenuButton` with role options
- Visual indicators (icons, checkmarks)
- Role descriptions
- Auto-navigation on switch
- Toast notifications

#### 3. Integration Points

**main.dart:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (context) => AppState()),
    ChangeNotifierProvider(create: (context) => RoleService()), // ⭐ Added
  ],
  child: MaterialApp(...)
)
```

**Dashboards:**
```dart
// Creator Dashboard
const CompactRoleSwitcher(),

// Approver Dashboard
const CompactRoleSwitcher(),
```

### Data Persistence

#### Storage
- **Method**: `SharedPreferences`
- **Key**: `'user_role'`
- **Value**: `UserRole.toString()` (e.g., "UserRole.creator")

#### Loading on Startup
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... other initialization
  
  // Load saved role is handled by RoleService
  // when it's initialized in the provider
}
```

## 🎨 UI/UX Details

### Role Switcher Appearance

**Compact Version:**
```
┌─────────────────┐
│ ✍️ 🔽          │
└─────────────────┘
```

**When Clicked:**
```
┌─────────────────────────────┐
│ ✍️ Creator              ✓  │ ← Active
│ Create and manage proposals │
├─────────────────────────────┤
│ ✅ Approver (CEO)          │
│ Review and approve proposals│
└─────────────────────────────┘
```

### Visual Feedback

**On Switch:**
```
Toast Notification:
┌───────────────────────────────┐
│ ✅ Switched to Approver mode  │
└───────────────────────────────┘
```

**Navigation:**
- Automatic redirect to role-appropriate dashboard
- Smooth transition (replaces current route)
- No back navigation to previous role's page

## 🔐 Permissions & Access Control

### Permission Checking

```dart
final roleService = Provider.of<RoleService>(context);

// Check permissions
if (roleService.canCreateProposals()) {
  // Show create button
}

if (roleService.canApproveProposals()) {
  // Show approval queue
}
```

### Role-Based Features

| Feature | Creator | Approver | Admin |
|---------|---------|----------|-------|
| Create Proposals | ✅ | ❌ | ✅ |
| Edit Proposals | ✅ | ❌ | ✅ |
| Approve Proposals | ❌ | ✅ | ✅ |
| Reject Proposals | ❌ | ✅ | ✅ |
| View Metrics | ✅ | ✅ | ✅ |
| System Settings | ❌ | ❌ | ✅ |

## 📱 Future: Separate Applications

### Roadmap

**Phase 1: Unified App with Roles** (Current) ✅
- Single application
- Role switcher in header
- Shared authentication
- Persistent role selection

**Phase 2: Separate Approver App** (Planned)
- Dedicated approver application
- Simplified UI focused on approvals
- Same backend/database
- Separate deployment

**Phase 3: Role-Based Apps** (Future)
```
├── Creator App (Main)
│   └── Full proposal management
├── Approver App
│   └── Approval-focused UI
└── Admin App
    └── System management
```

### Migration Path

**From Unified to Separate:**
1. Keep backend API unchanged
2. Extract approver pages to new project
3. Share authentication service
4. Deploy as separate web apps
5. Use subdomain routing (e.g., `approve.lukens.com`)

## 🧪 Testing

### Manual Testing

1. **Switch to Creator**
   - ✅ See dashboard with proposals
   - ✅ Can create new proposals
   - ✅ See "Create" buttons
   
2. **Switch to Approver**
   - ✅ See approval queue
   - ✅ Can approve/reject
   - ✅ See approval metrics
   
3. **Persistence**
   - ✅ Switch role
   - ✅ Refresh page
   - ✅ Role is remembered

4. **Navigation**
   - ✅ Switches to correct dashboard
   - ✅ No back button to wrong dashboard
   - ✅ Toast confirmation appears

## 🐛 Troubleshooting

### Role Not Persisting
**Problem**: Role resets on refresh
**Solution**: Check SharedPreferences permissions
```dart
await RoleService().loadSavedRole();
```

### Wrong Dashboard After Switch
**Problem**: Navigation doesn't change page
**Solution**: Check route names
```dart
Navigator.of(context).pushReplacementNamed('/approver_dashboard');
```

### Can't See Role Switcher
**Problem**: Widget not visible
**Solution**: Check if RoleService is in providers
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (context) => RoleService()),
  ],
  ...
)
```

## 📝 Example Usage

### In a Widget

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final roleService = Provider.of<RoleService>(context);
    
    return Column(
      children: [
        // Show role-specific content
        if (roleService.isCreator())
          ElevatedButton(
            onPressed: () => createProposal(),
            child: Text('Create Proposal'),
          ),
        
        if (roleService.isApprover())
          ElevatedButton(
            onPressed: () => viewApprovals(),
            child: Text('View Approvals'),
          ),
        
        // Add role switcher
        const RoleSwitcher(),
      ],
    );
  }
}
```

## 📊 Benefits

✅ **User Experience**
- Single login for multiple roles
- Quick switching between contexts
- Persistent preferences

✅ **Development**
- Clean separation of concerns
- Easy to add new roles
- Testable permission system

✅ **Future-Proof**
- Ready for separate apps
- Shared backend
- Scalable architecture

## 🔗 Related Documentation

- [Approver Dashboard](./APPROVER_DASHBOARD.md)
- [Creator Dashboard](./CREATOR_DASHBOARD.md)
- [Proposal Approval Workflow](./PROPOSAL_APPROVAL_WORKFLOW.md)
- [How to Access Approver Dashboard](../guides/HOW_TO_ACCESS_APPROVER_DASHBOARD.md)

---

**Status**: ✅ Complete and Production Ready
**Version**: 1.0
**Last Updated**: October 27, 2025
**Files Added**:
- `services/role_service.dart`
- `widgets/role_switcher.dart`
**Files Modified**:
- `main.dart` (Added MultiProvider with RoleService)
- `pages/creator/creator_dashboard_page.dart` (Added CompactRoleSwitcher)
- `pages/approver/approver_dashboard_page.dart` (Added CompactRoleSwitcher)

