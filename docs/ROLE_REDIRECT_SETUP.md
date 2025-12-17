# Role-Based Dashboard Redirect Setup

The application now redirects users to the appropriate dashboard based on their role after login.

## Role Mappings

### Backend Roles → Frontend Dashboards

| Backend Role | Frontend Role | Dashboard | Route |
|-------------|---------------|-----------|-------|
| `manager` | Creator | Manager Dashboard | `/creator_dashboard` |
| `financial manager` | Creator | Manager Dashboard | `/creator_dashboard` |
| `creator` | Creator | Manager Dashboard | `/creator_dashboard` |
| `admin` | Approver | Admin Dashboard | `/approver_dashboard` |
| `ceo` | Approver | Admin Dashboard | `/approver_dashboard` |
| `user` (default) | Creator | Manager Dashboard | `/creator_dashboard` |

## What Was Changed

### 1. Login Redirect (`login_page.dart`)
- ✅ Added role-based redirect logic
- ✅ Checks user role from backend
- ✅ Routes to appropriate dashboard:
  - **Manager/Financial Manager/Creator** → `/creator_dashboard`
  - **Admin/CEO** → `/approver_dashboard`

### 2. Role Service (`role_service.dart`)
- ✅ Updated role names:
  - `Creator` → **Manager**
  - `Approver` → **Admin**
- ✅ Added `mapBackendRoleToFrontendRole()` function
- ✅ Added `initializeRoleFromUser()` function
- ✅ Maps backend roles to frontend UserRole enum

### 3. Dashboard Pages
- ✅ **Creator Dashboard** (`creator_dashboard_page.dart`):
  - Shows "Manager Dashboard" for manager roles
  - Shows "Admin Dashboard" for admin roles (if accessed)
- ✅ **Approver Dashboard** (`approver_dashboard_page.dart`):
  - Shows "Admin" role label
  - Displays "CEO Executive Approvals" header

### 4. Role Switcher (`role_switcher.dart`)
- ✅ Updated navigation routes
- ✅ Creator role → `/creator_dashboard`
- ✅ Approver role → `/approver_dashboard`

### 5. HomeShell (`main.dart`)
- ✅ Added automatic redirect on app start
- ✅ Checks user role and redirects to appropriate dashboard

## How It Works

### Login Flow

1. User logs in with email/password
2. Backend returns user profile with `role` field
3. Frontend checks role:
   ```dart
   if (role == 'admin' || role == 'ceo') {
     → Navigate to /approver_dashboard
   } else {
     → Navigate to /creator_dashboard
   }
   ```
4. RoleService is initialized with user's role
5. User is redirected to appropriate dashboard

### App Startup Flow

1. App checks if user is logged in (from localStorage)
2. If logged in, HomeShell initializes
3. HomeShell checks user role
4. Automatically redirects to correct dashboard

## Testing

### Test Manager Login
1. Login with a user that has role `manager` or `financial manager`
2. Should redirect to `/creator_dashboard`
3. Dashboard should show "Manager Dashboard" header

### Test Admin Login
1. Login with a user that has role `admin` or `ceo`
2. Should redirect to `/approver_dashboard`
3. Dashboard should show "CEO Executive Approvals" header

## Role Display Names

- **Manager Dashboard**: Shows "Manager" role
- **Admin Dashboard**: Shows "Admin" role
- Role switcher shows: "Manager" and "Admin" options

## Notes

- Default role is `manager` (redirects to creator dashboard)
- Role is persisted in localStorage
- Role switcher allows switching between Manager and Admin views
- Backend role `user` defaults to Manager dashboard

