# Phase 2A Implementation - Multi-Credential RBAC System

**Completed:** 2026-01-11  
**Commit:** 0ef31f3  
**Status:** ✅ Complete

---

## Overview

Phase 2A implements a **multi-credential authentication system** with **exclusive portal access**. This architecture supports the O.A.S.I.S. business model where a single person can have multiple credentials (e.g., `user.soc` and `user.admin`), with each credential granting access to ONLY one portal.

### Key Principles

1. **Multi-Credential Model:** Each person can have multiple credentials
2. **Exclusive Access:** Each credential grants access to ONE portal only
3. **Separation of Duties:** Admin actions are separate from SOC analyst work
4. **Audit Trail:** System logs which credential was used for each action

---

## Architecture Changes

### Before Phase 2A (Traditional RBAC)
```
User → Single login → Multiple roles/permissions → Access to multiple areas
```

### After Phase 2A (Multi-Credential RBAC)
```
Person → Multiple credentials → Each credential = ONE portal access
  ├─ user.soc (credential_type: soc_analyst) → /dashboard/* ONLY
  └─ user.admin (credential_type: platform_admin) → /admin/* ONLY
```

---

## Database Schema Changes

### New Table: `credentials`

```sql
CREATE TYPE credential_type AS ENUM ('soc_analyst', 'platform_admin', 'customer_user');

CREATE TABLE credentials (
    credential_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(255) NOT NULL UNIQUE,           -- e.g., 'user.soc', 'user.admin'
    password_hash TEXT NOT NULL,
    credential_type credential_type NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    UNIQUE(user_id, credential_type)                 -- One credential per type per user
);
```

**Key Features:**
- `credential_id`: Unique identifier for tracking which credential was used
- `user_id`: Links back to the person (users table)
- `username`: Unique login name (e.g., `user.soc`, `user.admin`)
- `credential_type`: Determines which portal this credential can access
- `last_used_at`: Tracks last successful login for this credential
- **UNIQUE constraint**: Each user can have only ONE credential per type

### Updated Table: `users`

```sql
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
```

The `users` table now represents the **person**, while `credentials` represents their **login identities**.

### Test Data Created

```sql
-- Person (user)
user_id: 94d151bc-3428-49c2-a203-e4e321a427c7
email: admin@oasis.local
full_name: Admin User

-- SOC Analyst Credential
credential_id: bea1b1e3-78b9-4a8b-afbd-5d22b3a3ea9e
username: user.soc
credential_type: soc_analyst
password: Admin123!

-- Platform Admin Credential
credential_id: 10710a10-fea1-4f94-a85c-2e4dcb7833ae
username: user.admin
credential_type: platform_admin
password: Admin123!
```

---

## Backend API Changes

### Login Endpoint (`POST /auth/login`)

**Old Query:**
```python
SELECT id, tenant_id, username, password_hash, role, is_active
FROM users
WHERE username = $1
```

**New Query:**
```python
SELECT 
    c.credential_id,
    c.user_id,
    c.username,
    c.password_hash,
    c.credential_type,
    c.is_active,
    u.email,
    u.full_name,
    u.tenant_id
FROM credentials c
JOIN users u ON c.user_id = u.id
WHERE c.username = $1 AND c.is_active = true
```

### JWT Token Structure

**Old Payload:**
```json
{
  "sub": "user_id",
  "tenant_id": "tenant_id",
  "role": "platform_admin",
  "username": "admin"
}
```

**New Payload:**
```json
{
  "sub": "user_id",
  "credential_id": "credential_id",
  "credential_type": "platform_admin",
  "username": "user.admin",
  "email": "admin@oasis.local",
  "tenant_id": "tenant_id",
  "exp": 1768170386,
  "iat": 1768166786
}
```

**Key Changes:**
- Added `credential_id` for audit trail
- Renamed `role` → `credential_type` for clarity
- Added `email` for user display
- Tracks `iat` (issued at) and `exp` (expiration)

### Authorization Checks

**Old Pattern (11 instances):**
```python
if current_user["role"] not in ["super_admin", "admin"]:
    raise HTTPException(403, "Only administrators...")
```

**New Pattern:**
```python
if current_user["credential_type"] != "platform_admin":
    raise HTTPException(403, "Only administrators...")
```

**Affected Endpoints:**
- `/admin/*` routes (all require `platform_admin`)
- `/users/*` endpoints (user management)
- `/system/*` endpoints (system configuration)

### API Response Changes

**LoginResponse Model:**
```python
class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    credential_id: str          # ← Added
    tenant_id: Optional[str]
    credential_type: str        # ← Changed from 'role'
```

---

## Frontend Changes

### Middleware (`frontend/middleware.ts`)

**Exclusive Access Enforcement:**

```typescript
// Admin Portal - platform_admin credentials ONLY
if (pathname.startsWith('/admin')) {
  if (credentialType !== 'platform_admin') {
    // Wrong credentials → redirect to login with error
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('error', 'wrong_portal');
    loginUrl.searchParams.set('message', 'Please log in with admin credentials');
    return NextResponse.redirect(loginUrl);
  }
}

// SOC Portal - soc_analyst credentials ONLY
if (pathname.startsWith('/dashboard')) {
  if (credentialType !== 'soc_analyst') {
    // Wrong credentials → redirect to login with error
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('error', 'wrong_portal');
    loginUrl.searchParams.set('message', 'Please log in with SOC analyst credentials');
    return NextResponse.redirect(loginUrl);
  }
}
```

**Root Path Redirect:**
```typescript
if (pathname === '/') {
  if (credentialType === 'soc_analyst') {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  } else if (credentialType === 'platform_admin') {
    return NextResponse.redirect(new URL('/admin', request.url));
  }
}
```

### Auth Context (`frontend/contexts/AuthContext.tsx`)

**Login Flow:**
```typescript
const login = async (credentials: LoginRequest) => {
  const response = await authApi.login(credentials);
  const { access_token } = response;
  
  tokenUtils.setToken(access_token);
  const decoded = tokenUtils.decodeToken(access_token);
  setUser(decoded);
  
  // Redirect based on credential type
  if (decoded.credential_type === 'soc_analyst') {
    router.push('/dashboard');
  } else if (decoded.credential_type === 'platform_admin') {
    router.push('/admin');
  }
};
```

### User Interface (`frontend/lib/api.ts`)

```typescript
export interface User {
  user_id: string;
  credential_id: string;        // ← Added
  credential_type: string;      // ← Changed from 'role'
  username: string;
  email: string;                // ← Added
  tenant_id: string;
}
```

---

## Portal Updates

### Admin Portal

#### New Component: AdminSidebar

**Features:**
- Purple/admin branding (different from SOC's green/blue)
- Navigation links:
  - 🏠 Overview (`/admin`)
  - 👥 User Management (`/admin/users`)
  - ⚙️ System Settings (`/admin/settings`)
- Portal badge showing "🔒 ADMIN PORTAL"
- User info section showing username and "Platform Administrator"
- 🚪 Logout button at bottom

**File:** `frontend/components/AdminSidebar.tsx` (124 lines)

#### Updated Admin Layout

**File:** `frontend/app/admin/layout.tsx`

**Before:** Just a header banner  
**After:** Full layout with sidebar

```tsx
export default function AdminLayout({ children }: { children: ReactNode }) {
  // Check credential_type instead of role
  useEffect(() => {
    if (!isLoading && user && user.credential_type !== 'platform_admin') {
      router.push('/login?error=access_denied');
    }
  }, [user, isLoading, router]);
  
  if (!user || user.credential_type !== 'platform_admin') {
    return null;
  }

  return (
    <div className="min-h-screen" style={{ background: 'var(--background)' }}>
      <AdminSidebar />
      <div className="ml-64">
        <div className="p-8">
          {children}
        </div>
      </div>
    </div>
  );
}
```

#### Updated Admin Overview

**File:** `frontend/app/admin/page.tsx`

**Before:** Grid of cards with links  
**After:** System metrics dashboard

Shows:
- 📝 Total Logs
- 📡 Sources
- ⚡ Ingestion Rate
- 🖥️ System Status (healthy_services/total_services)
- Platform Information (version, credential type, architecture)

### SOC Portal (SOCAP)

#### Removed Admin Links

**File:** `frontend/app/dashboard/layout.tsx`

**Before:**
```typescript
const settingsNavigation = 
  user?.role === 'platform_admin'
    ? [
        { name: 'User Management', href: '/admin/users', icon: '👥' },
        { name: 'System Settings', href: '/admin/settings', icon: '⚙️' },
      ]
    : [];
```

**After:**
```typescript
const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: '📊' },
  { name: 'Logs', href: '/dashboard/logs', icon: '📝' },
  { name: 'Analytics', href: '/dashboard/analytics', icon: '📈' },
  { name: 'Alerts', href: '/dashboard/alerts', icon: '🔔' },
  { name: 'Tenant Settings', href: '/dashboard/settings', icon: '🏢' },  // ← Added
];

// Removed: settingsNavigation section
```

**Result:** SOC portal sidebar NO LONGER shows admin links, even for users who have admin credentials.

#### Added Tenant Settings

**File:** `frontend/app/dashboard/settings/page.tsx`

**Before:** Placeholder saying "Settings not implemented"  
**After:** Tenant Settings page with placeholder cards

Shows:
- 🏢 Tenant Information (Coming in Phase 2C)
- 🔑 API Keys (Coming in Phase 2C) - **grayed out (opacity: 0.6)**
- 📡 Agent Configuration (Coming in Phase 2C)
- 🔔 Notification Settings (Coming in Phase 2C)

### Login Page

**File:** `frontend/app/login/page.tsx`

Added credential display:
```tsx
<div className="mt-6 p-4 bg-slate-900 rounded-lg border border-slate-700">
  <p className="text-xs font-semibold text-slate-300 mb-2 text-center">
    Development Credentials:
  </p>
  <div className="space-y-2 text-xs">
    <div className="flex justify-between items-center p-2 bg-slate-800 rounded">
      <span className="text-slate-400">SOC Analyst:</span>
      <span className="text-blue-400 font-mono">user.soc / Admin123!</span>
    </div>
    <div className="flex justify-between items-center p-2 bg-slate-800 rounded">
      <span className="text-slate-400">Platform Admin:</span>
      <span className="text-purple-400 font-mono">user.admin / Admin123!</span>
    </div>
  </div>
</div>
```

---

## Testing

### Backend API Tests

**SOC Login:**
```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user.soc", "password": "Admin123!"}'

# Returns:
{
  "access_token": "eyJ...",
  "user_id": "94d151bc-3428-49c2-a203-e4e321a427c7",
  "credential_id": "bea1b1e3-78b9-4a8b-afbd-5d22b3a3ea9e",
  "credential_type": "soc_analyst",
  "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff"
}
```

**Admin Login:**
```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user.admin", "password": "Admin123!"}'

# Returns:
{
  "access_token": "eyJ...",
  "credential_id": "10710a10-fea1-4f94-a85c-2e4dcb7833ae",
  "credential_type": "platform_admin",
  ...
}
```

**JWT Payload Verification:**
```bash
# Decode SOC token
curl ... | jq -r '.access_token' | cut -d'.' -f2 | base64 -d

{
  "sub": "94d151bc-3428-49c2-a203-e4e321a427c7",
  "credential_id": "bea1b1e3-78b9-4a8b-afbd-5d22b3a3ea9e",
  "credential_type": "soc_analyst",
  "username": "user.soc",
  "email": "admin@oasis.local",
  "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff"
}
```

### Frontend Tests (Manual)

✅ Login as `user.soc` → redirects to `/dashboard`  
✅ Login as `user.admin` → redirects to `/admin`  
✅ Admin portal shows sidebar with logout button  
✅ Admin portal shows system metrics  
✅ SOC portal shows "Tenant Settings" in navigation  
✅ SOC portal does NOT show admin links  
✅ Tenant Settings page shows placeholder cards with API Keys grayed out  
✅ Middleware blocks cross-portal access (wrong credentials redirect to login)

---

## Database Migration

### Forward Migration

**File:** `migrations/phase2a_multi_credential.sql`

```bash
docker exec oasis-postgresql psql -U admin -d oasis -f /migrations/phase2a_multi_credential.sql
```

**Creates:**
1. `credential_type` enum
2. `credentials` table
3. Test credentials (user.soc, user.admin)
4. Grants permissions to api_user

### Rollback Migration

**File:** `migrations/phase2a_multi_credential_rollback.sql`

```bash
docker exec oasis-postgresql psql -U admin -d oasis -f /migrations/phase2a_multi_credential_rollback.sql
```

**Removes:**
1. Test credentials
2. `credentials` table
3. `credential_type` enum
4. `full_name` column from users

---

## Known Issues & Future Work

### Issue 1: Old `admin` user still exists

The old `users` table still has the original `admin` user with `role: platform_admin`. This user can technically still log in but uses the OLD authentication flow.

**Not a problem because:**
- Middleware and layouts check `credential_type`, which old tokens don't have
- Old admin user will be blocked by frontend layout checks
- Migration should eventually remove old test users

### Issue 2: User Management uses old `role` field

The `/admin/users` page manages users with the old `role` field. This is intentional - full credential management comes in Phase 2B/2C.

**Current behavior:**
- Admins can create/edit users with roles
- But login requires credentials from `credentials` table
- This will be updated in Phase 2B when we add credential management UI

### Future Work (Phase 2B)

**Tenant Agent Limits:**
- Per-tenant agent count limits
- Agent registration with tenant validation
- Tenant creation workflow

**Credential Management UI:**
- Admin portal: Manage credentials for users
- Create/revoke credentials
- View credential activity (last_used_at)

---

## Files Modified

### Backend
- `services/api-service/src/main.py` (100 changes)

### Frontend
- `frontend/middleware.ts` (65 changes)
- `frontend/contexts/AuthContext.tsx` (11 changes)
- `frontend/lib/api.ts` (10 changes)
- `frontend/lib/auth.ts` (14 changes)
- `frontend/app/login/page.tsx` (16 changes)
- `frontend/app/admin/layout.tsx` (46 changes)
- `frontend/app/admin/page.tsx` (182 changes)
- `frontend/app/dashboard/layout.tsx` (48 changes)
- `frontend/app/dashboard/settings/page.tsx` (139 changes)

### New Files
- `frontend/components/AdminSidebar.tsx` (124 lines)
- `migrations/phase2a_multi_credential.sql` (128 lines)
- `migrations/phase2a_multi_credential_rollback.sql` (21 lines)

**Total Changes:** 13 files changed, 632 insertions(+), 272 deletions(-)

---

## Key Takeaways

1. **Multi-Credential Architecture:** Successfully implemented a system where each person can have multiple credentials, each granting exclusive access to one portal
2. **Separation of Duties:** Admin credentials are completely separate from SOC analyst work
3. **Audit Trail:** System now tracks which credential (credential_id) was used for each action
4. **Security:** Middleware enforces exclusive access at the route level
5. **User Experience:** Clear credential display on login page, appropriate redirects based on credential type
6. **Database Design:** Clean separation between people (users) and login identities (credentials)

---

## Test Credentials Summary

| Username | Password | Credential Type | Portal Access |
|----------|----------|----------------|---------------|
| `user.soc` | `Admin123!` | `soc_analyst` | `/dashboard/*` |
| `user.admin` | `Admin123!` | `platform_admin` | `/admin/*` |

Both credentials belong to the same person (user_id: `94d151bc-3428-49c2-a203-e4e321a427c7`).
