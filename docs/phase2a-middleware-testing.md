# Phase 2A Middleware Testing Guide

## Test Users

The following test users are available in the database:

| Username   | Email                     | Password  | Role            | Purpose                        |
|------------|---------------------------|-----------|-----------------|--------------------------------|
| `admin`    | admin@oasis.local         | admin123  | platform_admin  | Full admin access              |
| `analyst`  | analyst@oasis.local       | admin123  | soc_analyst     | SOC analyst (limited access)   |
| `nonadmin` | gruber.aaron@gmail.com    | (set)     | customer_user   | Customer portal user           |

## Test Scenarios

### Scenario 1: Platform Admin Access
**User:** `admin` / `admin@oasis.local`

**Expected Behavior:**
- ✅ Can access `/dashboard` and all sub-routes
- ✅ Can access `/users` (User Management)
- ✅ Can access `/system-settings` (System Settings)
- ✅ Can access `/admin/*` routes (when implemented)
- ✅ Settings section shows in sidebar navigation

**Test Steps:**
1. Login as `admin@oasis.local`
2. Verify dashboard loads successfully
3. Click "User Management" - should load without redirect
4. Click "System Settings" - should load without redirect
5. Manually navigate to `/admin/test` - should not redirect (404 is OK)

---

### Scenario 2: SOC Analyst Access
**User:** `analyst` / `analyst@oasis.local`

**Expected Behavior:**
- ✅ Can access `/dashboard` and all sub-routes
- ✅ Can access `/users` (User Management)
- ✅ Can access `/system-settings` (System Settings)
- ❌ CANNOT access `/admin/*` routes
- ❌ Settings section HIDDEN in sidebar (not platform_admin)

**Test Steps:**
1. Login as `analyst@oasis.local`
2. Verify dashboard loads successfully
3. Verify Settings section is NOT visible in sidebar
4. Manually navigate to `/admin/test` in browser
5. **Expected:** Redirect to `/dashboard` with error message "Access Denied: You do not have permission to access that resource."
6. Error message should auto-dismiss after 8 seconds

---

### Scenario 3: Customer User Access
**User:** `nonadmin` / `gruber.aaron@gmail.com`

**Expected Behavior:**
- ❌ CANNOT access `/dashboard` or SOC portal routes
- ❌ CANNOT access `/users`
- ❌ CANNOT access `/system-settings`
- ❌ CANNOT access `/admin/*` routes
- ✅ Should be redirected to `/login` with error

**Test Steps:**
1. Login as `gruber.aaron@gmail.com`
2. After login, check redirect behavior
3. **Expected:** Redirect to `/login` with error "Invalid Portal: Please use the customer portal to access your account."
4. Try manually navigating to `/dashboard` - should redirect to login
5. Try manually navigating to `/admin/test` - should redirect to login

**Note:** Customer portal will be implemented in Phase 2D. For now, customer_user role has no accessible routes.

---

### Scenario 4: Unauthenticated Access
**User:** (not logged in)

**Expected Behavior:**
- ❌ CANNOT access any protected routes
- ✅ Can access `/login` page only
- ✅ Redirected to `/login?redirect=<original-path>` when accessing protected route

**Test Steps:**
1. Logout if currently logged in
2. Try accessing `/dashboard` - should redirect to `/login?redirect=%2Fdashboard`
3. Try accessing `/users` - should redirect to `/login` with redirect param
4. Try accessing `/admin/test` - should redirect to `/login` with redirect param
5. Access `/login` - should load successfully

---

### Scenario 5: Expired Token
**User:** (any user with expired token)

**Expected Behavior:**
- ❌ Token expired → redirect to `/login?expired=true`
- ⚠️ Shows warning: "Session Expired: Your session has expired. Please log in again."

**Test Steps:**
1. Login as any user
2. Wait for token to expire (24 hours) OR manually edit cookie expiration
3. Try accessing any protected route
4. **Expected:** Redirect to `/login?expired=true` with yellow warning message

---

### Scenario 6: Direct Login → Dashboard Redirect
**User:** (any authenticated user)

**Expected Behavior:**
- If user tries to access `/login` while authenticated, redirect to `/dashboard`

**Test Steps:**
1. Login as any user
2. Navigate to `/dashboard` - verify loaded
3. Manually navigate to `/login` in browser
4. **Expected:** Immediate redirect back to `/dashboard`

---

### Scenario 7: Query Parameter Alerts
**User:** (any user)

**Expected Behavior:**
- Access denied error shows red alert with 🚫 icon
- Session expired shows yellow alert with ⚠️ icon
- Alerts auto-dismiss after 8 seconds
- Clicking ✕ immediately dismisses alert
- Query parameters cleared from URL after dismiss

**Test Steps:**
1. Trigger access denied (e.g., analyst accessing `/admin/test`)
2. Verify red alert appears with correct message
3. Wait 8 seconds - alert should disappear
4. Trigger again, click ✕ - alert should immediately disappear
5. Check URL - `?error=access_denied` should be removed

---

## Middleware Logic Summary

```
/login                    → Public (redirects to /dashboard if authenticated)
/api/auth/*               → Public (auth endpoints)

/dashboard/*              → soc_analyst + platform_admin
/users                    → soc_analyst + platform_admin
/system-settings          → soc_analyst + platform_admin

/admin/*                  → platform_admin ONLY (not yet implemented)

/                         → Redirect to /dashboard (if authenticated)
```

## Known Limitations (Phase 2A)

- Customer users (`customer_user` role) have no accessible routes yet
  - Will be addressed in Phase 2D with Customer Portal
- `/admin/*` routes return 404 (not yet implemented)
  - Will be created during route group refactoring
- SOC analysts can currently access User Management and System Settings
  - These will move to `/admin/*` during refactoring, then analysts will be blocked

## Middleware Files

- `frontend/middleware.ts` - Main middleware logic
- `frontend/components/QueryParamAlert.tsx` - Error alert component
- `frontend/app/dashboard/layout.tsx` - Includes QueryParamAlert

## Testing Checklist

- [ ] Scenario 1: Platform Admin Access
- [ ] Scenario 2: SOC Analyst Access
- [ ] Scenario 3: Customer User Access
- [ ] Scenario 4: Unauthenticated Access
- [ ] Scenario 5: Expired Token
- [ ] Scenario 6: Login Page Redirect
- [ ] Scenario 7: Query Parameter Alerts

## Next Steps

After middleware testing is complete:
1. Refactor routes into groups: `(socap)` and `admin`
2. Move `/users` → `/admin/users`
3. Move `/system-settings` → `/admin/settings`
4. Update navigation links in dashboard layout
5. Test middleware with new route structure
