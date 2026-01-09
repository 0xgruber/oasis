## ADDED Requirements

### Requirement: User Authentication UI (Phase 1)
The system SHALL provide secure login with username/password and TOTP two-factor authentication.

#### Scenario: Login page
- **WHEN** an unauthenticated user accesses the application
- **THEN** the system displays a login form with username and password fields
- **AND** provides a "Login" button
- **AND** redirects to login page from any protected route

#### Scenario: Login with TOTP
- **WHEN** a user submits valid username and password
- **THEN** the system prompts for TOTP code (6 digits)
- **AND** validates TOTP against user's stored secret
- **AND** issues JWT token with 1h expiration and tenant_id claim on success

#### Scenario: Login failure
- **WHEN** a user submits invalid credentials or TOTP
- **THEN** the system displays error message "Invalid credentials or TOTP code"
- **AND** increments failed login counter (rate limit after 5 failures)
- **AND** logs failed attempt to audit_logs

#### Scenario: JWT token refresh
- **WHEN** JWT token is within 5 minutes of expiration
- **THEN** the system automatically refreshes token via /auth/refresh endpoint
- **AND** updates token in localStorage
- **AND** retries failed request with new token

#### Scenario: Logout
- **WHEN** a user clicks "Logout"
- **THEN** the system clears JWT token from localStorage
- **AND** redirects to login page
- **AND** logs logout to audit_logs

### Requirement: RBAC UI Enforcement (Phase 1)
The system SHALL enforce role-based access control by showing/hiding UI elements based on user role.

#### Scenario: Super Admin UI
- **WHEN** user with role "super_admin" logs in
- **THEN** the system shows all navigation menu items (tenants, API keys, certificates, system config, audit logs)
- **AND** enables all CRUD operations

#### Scenario: Internal SOC UI
- **WHEN** user with role "internal_soc" logs in
- **THEN** the system shows log viewer, saved searches, dashboard
- **AND** hides tenant management, certificates, system config
- **AND** restricts log queries to "Internal" tenant only

#### Scenario: SOC Operator UI
- **WHEN** user with role "soc_operator" logs in
- **THEN** the system shows read-only log viewer and dashboard
- **AND** disables saved searches, export, and configuration

#### Scenario: Tenant User UI (Phase 2)
- **WHEN** user with role "tenant_user" logs in
- **THEN** the system shows Customer Portal (separate deployment)
- **AND** restricts log queries to user's tenant only
- **AND** hides all admin features

### Requirement: Tenant Management UI (Phase 1A: Weeks 1-3)
The system SHALL provide CRUD interface for managing tenants.

#### Scenario: Tenant list view
- **WHEN** super admin navigates to /tenants
- **THEN** the system displays table of all tenants with columns: name, UUID, created_at, retention_days, rate_limit_eps, is_active
- **AND** provides "Create Tenant" button
- **AND** shows action buttons for edit and delete per row

#### Scenario: Create tenant
- **WHEN** super admin clicks "Create Tenant"
- **THEN** the system displays modal with fields: name, retention_days (default 90), rate_limit_eps (default 10000)
- **AND** validates name is unique
- **AND** generates API key automatically on creation
- **AND** displays API key once (full key, never shown again)

#### Scenario: Edit tenant
- **WHEN** super admin clicks edit icon for a tenant
- **THEN** the system displays modal with current values
- **AND** allows editing name, retention_days, rate_limit_eps, is_active
- **AND** validates changes before saving
- **AND** logs changes to audit_logs

#### Scenario: Delete tenant with confirmation
- **WHEN** super admin clicks delete icon for a tenant
- **THEN** the system displays confirmation modal with warning "This will permanently delete all logs for this tenant"
- **AND** requires typing tenant name to confirm
- **AND** deletes tenant from PostgreSQL and drops ClickHouse table on confirm
- **AND** logs deletion to audit_logs

### Requirement: API Key Management UI (Phase 1A: Weeks 1-3)
The system SHALL provide interface for viewing and regenerating tenant API keys.

#### Scenario: View API key prefix
- **WHEN** super admin views tenant list or tenant detail page
- **THEN** the system displays API key prefix (e.g., "oasis_pk_abc12345")
- **AND** masks remaining characters (never displays full key after creation)

#### Scenario: Regenerate API key
- **WHEN** super admin clicks "Regenerate API Key" for a tenant
- **THEN** the system displays confirmation modal with warning "Old API key will stop working immediately"
- **AND** requires password re-entry to confirm
- **AND** generates new API key, invalidates old key
- **AND** displays new full API key once (modal with copy button)
- **AND** logs regeneration to audit_logs

#### Scenario: Copy API key to clipboard
- **WHEN** API key is displayed in modal after creation/regeneration
- **THEN** the system provides "Copy to Clipboard" button
- **AND** shows toast notification "API key copied"
- **AND** warns "This key will not be shown again"

### Requirement: Health Dashboard (Phase 1A: Weeks 1-3)
The system SHALL provide real-time system health and metrics dashboard.

#### Scenario: Service status indicators
- **WHEN** user views dashboard
- **THEN** the system displays status for each service: external gateway, internal gateway, ingestion service, API service, ClickHouse, PostgreSQL
- **AND** shows green/yellow/red indicators (healthy, degraded, down)
- **AND** updates status every 30 seconds via polling or WebSocket

#### Scenario: Ingestion rate metrics
- **WHEN** user views dashboard
- **THEN** the system displays current ingestion rate (EPS) per tenant
- **AND** shows chart of ingestion rate over last 24 hours
- **AND** displays total events ingested today

#### Scenario: Resource usage metrics
- **WHEN** user views dashboard
- **THEN** the system displays memory usage per service (% of limit)
- **AND** shows disk usage for ClickHouse and PostgreSQL
- **AND** warns if any resource exceeds 80% usage

#### Scenario: Recent errors
- **WHEN** user views dashboard
- **THEN** the system displays last 10 errors from backend services
- **AND** shows error timestamp, service name, error message
- **AND** provides link to full audit logs

### Requirement: Certificate Management UI (Phase 1B: Weeks 4-6)
The system SHALL provide interface for viewing and regenerating TLS certificates.

#### Scenario: Certificate list view
- **WHEN** super admin navigates to /certificates
- **THEN** the system displays table of all certificates: name (e.g., "external-gateway"), issuer, expires_at, status (valid/expiring/expired)
- **AND** shows status indicator: green (>30 days), yellow (<30 days), red (expired)

#### Scenario: View certificate details
- **WHEN** super admin clicks a certificate row
- **THEN** the system expands row to show certificate PEM, serial number, subject, issuer details

#### Scenario: Download certificate
- **WHEN** super admin clicks "Download" for a certificate
- **THEN** the system downloads certificate as .pem file (certificate only, not private key)
- **AND** logs download to audit_logs

#### Scenario: Regenerate certificate with re-authentication
- **WHEN** super admin clicks "Regenerate" for a certificate
- **THEN** the system displays modal requiring password + TOTP re-entry
- **AND** validates credentials
- **AND** generates new certificate, updates PostgreSQL
- **AND** restarts affected Docker containers via Docker API
- **AND** displays success message with new expiration date
- **AND** logs regeneration to audit_logs

### Requirement: RBAC Management UI (Phase 1B: Weeks 4-6)
The system SHALL provide interface for managing users and role assignments.

#### Scenario: User list view
- **WHEN** super admin navigates to /users
- **THEN** the system displays table of users: username, email, role, tenant, last_login_at
- **AND** provides "Create User" button
- **AND** shows filter dropdown for role (show all, super_admin only, etc.)

#### Scenario: Create user
- **WHEN** super admin clicks "Create User"
- **THEN** the system displays form with fields: username, email, password, role (dropdown), tenant_id (nullable)
- **AND** validates password complexity (min 12 chars, uppercase, lowercase, number, symbol)
- **AND** generates TOTP secret and displays QR code for scanning
- **AND** creates user and logs to audit_logs

#### Scenario: Change user role
- **WHEN** super admin changes a user's role via dropdown
- **THEN** the system updates role in PostgreSQL
- **AND** displays confirmation toast "Role updated"
- **AND** logs role change to audit_logs with old and new role

#### Scenario: Disable user account
- **WHEN** super admin toggles user "is_active" to false
- **THEN** the system prevents that user from logging in
- **AND** invalidates existing JWT tokens (Phase 2: token blacklist)
- **AND** logs account disable to audit_logs

### Requirement: Retention Policy Configuration UI (Phase 1B: Weeks 4-6)
The system SHALL provide interface for configuring per-tenant and global log retention policies.

#### Scenario: View retention policies
- **WHEN** super admin navigates to /settings/retention
- **THEN** the system displays global default retention (90 days)
- **AND** shows list of tenant-specific overrides

#### Scenario: Update global retention policy
- **WHEN** super admin updates global retention days (e.g., 180)
- **THEN** the system requires password + TOTP re-authentication
- **AND** updates system_config table
- **AND** applies to new tenants (existing tenants retain custom values)
- **AND** logs change to audit_logs

#### Scenario: Update per-tenant retention policy
- **WHEN** super admin sets custom retention for tenant "Acme Corp" (e.g., 365 days)
- **THEN** the system updates tenants.retention_days
- **AND** alters ClickHouse TTL for that tenant's table
- **AND** logs change to audit_logs

### Requirement: Rate Limit Configuration UI (Phase 1B: Weeks 4-6)
The system SHALL provide interface for configuring per-tenant rate limits.

#### Scenario: View rate limits
- **WHEN** super admin navigates to /settings/rate-limits
- **THEN** the system displays table: tenant name, current rate limit (EPS), last updated
- **AND** shows global default rate limit (10,000 EPS)

#### Scenario: Update tenant rate limit
- **WHEN** super admin changes rate limit for tenant to 50,000 EPS
- **THEN** the system updates tenants.rate_limit_eps
- **AND** gateway reloads configuration within 60 seconds
- **AND** logs change to audit_logs

### Requirement: Advanced System Configuration UI (Phase 1C: Week 7+)
The system SHALL provide interface for advanced system configuration requiring re-authentication.

#### Scenario: Database connection configuration
- **WHEN** super admin navigates to /settings/database
- **THEN** the system displays forms for ClickHouse and PostgreSQL connection strings
- **AND** requires password + TOTP re-authentication before viewing or editing
- **AND** masks passwords in connection strings (shows ****)
- **AND** validates connection before saving (test query)

#### Scenario: SMTP configuration
- **WHEN** super admin navigates to /settings/smtp
- **THEN** the system displays form: SMTP host, port, username, password, from_address, use_TLS
- **AND** requires re-authentication
- **AND** provides "Send Test Email" button
- **AND** logs configuration changes to audit_logs

#### Scenario: Backup/restore UI
- **WHEN** super admin navigates to /settings/backup
- **THEN** the system displays "Trigger Backup" button
- **AND** shows list of existing backups with timestamps
- **AND** provides "Restore" button per backup (requires confirmation + re-auth)
- **AND** displays backup status (in progress, completed, failed)

#### Scenario: Docker resource limits configuration
- **WHEN** super admin navigates to /settings/docker
- **THEN** the system displays sliders for memory and CPU limits per service
- **AND** requires re-authentication to save changes
- **AND** updates docker-compose.yml or Docker API to apply limits
- **AND** warns if changes require service restart

### Requirement: Audit Log Viewer (Phase 1C: Week 7+)
The system SHALL provide interface for viewing and filtering audit logs.

#### Scenario: Audit log list view
- **WHEN** super admin navigates to /audit-logs
- **THEN** the system displays table: timestamp, user, action, resource_type, resource_id, IP, status_code
- **AND** defaults to last 7 days
- **AND** supports pagination (100 rows per page)

#### Scenario: Filter audit logs
- **WHEN** super admin applies filters (user, tenant, action, date range)
- **THEN** the system queries PostgreSQL audit_logs table
- **AND** updates table with filtered results
- **AND** shows result count

#### Scenario: Export audit logs to CSV
- **WHEN** super admin clicks "Export to CSV"
- **THEN** the system generates CSV file with all filtered audit logs
- **AND** includes all columns including metadata JSONB (flattened)
- **AND** logs export action to audit_logs

### Requirement: Log Viewer Component
The system SHALL provide table-based interface for viewing and filtering security logs with tenant isolation.

#### Scenario: Display recent logs for user's tenant
- **WHEN** user views /logs
- **THEN** the system queries logs_{tenant_uuid} table based on JWT tenant_id claim
- **AND** displays 100 most recent logs by default
- **AND** shows columns: timestamp, severity, category, class, source_ip, user, message
- **AND** supports column show/hide and reorder

#### Scenario: Pagination
- **WHEN** user scrolls to bottom of log table
- **THEN** the system loads next 100 logs
- **AND** maintains scroll position
- **AND** indicates loading state with skeleton UI

#### Scenario: Log detail expansion
- **WHEN** user clicks a log row
- **THEN** the system expands row to show full OCSF fields (nested JSON viewer)
- **AND** displays raw_log in formatted text
- **AND** provides "Copy JSON" button

#### Scenario: Time range filter
- **WHEN** user selects time range (last 1h, 24h, 7d, 30d, custom)
- **THEN** the system queries logs within that range for user's tenant
- **AND** updates table and displays result count

#### Scenario: Severity filter
- **WHEN** user selects one or more severity levels (info, warning, error, critical)
- **THEN** the system filters logs by selected severities
- **AND** applies WHERE clause in ClickHouse query

#### Scenario: Full-text search
- **WHEN** user enters text in search box (e.g., "192.168.1.1")
- **THEN** the system searches across message, source_ip, dest_ip, user_name fields
- **AND** highlights matching text in results
- **AND** debounces input (500ms delay)

#### Scenario: Save search
- **WHEN** user clicks "Save Search" with active filters
- **THEN** the system displays modal to name the search
- **AND** saves filters to PostgreSQL saved_searches table
- **AND** displays saved searches in sidebar for quick access

#### Scenario: Export logs
- **WHEN** user clicks "Export" with filtered logs
- **THEN** the system displays modal with format options (CSV, JSON)
- **AND** generates file with up to 10,000 filtered logs
- **AND** logs export action to audit_logs

### Requirement: Re-authentication Modal for Sensitive Operations
The system SHALL require password + TOTP re-entry for sensitive configuration changes.

#### Scenario: Trigger re-authentication
- **WHEN** user attempts sensitive action (certificate regeneration, system config change)
- **THEN** the system displays modal with password and TOTP fields
- **AND** validates credentials via POST /auth/reauth
- **AND** issues short-lived token (5 minutes) for sensitive operation

#### Scenario: Re-authentication failure
- **WHEN** user enters invalid password or TOTP in re-auth modal
- **THEN** the system displays error "Invalid credentials"
- **AND** does not proceed with sensitive action
- **AND** logs failed re-auth attempt to audit_logs

### Requirement: Error Handling and User Feedback
The system SHALL provide clear error messages and loading states.

#### Scenario: API error handling
- **WHEN** an API request fails (network error, 500 error)
- **THEN** the system displays toast notification with user-friendly message
- **AND** logs full error to browser console
- **AND** provides "Retry" button for recoverable errors

#### Scenario: Loading states
- **WHEN** data is being fetched from API
- **THEN** the system displays skeleton UI or spinner
- **AND** disables interactive elements during loading
- **AND** provides cancel option for long-running queries (>5s)

#### Scenario: Empty state
- **WHEN** no logs match current filters
- **THEN** the system displays "No logs found" with icon
- **AND** suggests adjusting filters or time range

### Requirement: Performance and Responsiveness
The system SHALL provide responsive UI with minimal perceived latency.

#### Scenario: Initial page load
- **WHEN** user first loads dashboard
- **THEN** the page renders within 2 seconds
- **AND** uses server-side rendering (Next.js SSR)
- **AND** displays cached data immediately, updates asynchronously

#### Scenario: Search responsiveness
- **WHEN** user applies filters
- **THEN** the UI updates within 500ms
- **AND** debounces rapid filter changes
- **AND** cancels pending requests when filters change

### Requirement: API Client Integration
The system SHALL provide type-safe API client for communicating with backend.

#### Scenario: TypeScript API client
- **WHEN** frontend makes API request
- **THEN** the system uses generated TypeScript types from OpenAPI spec
- **AND** validates request parameters at compile time
- **AND** types response data for autocomplete in IDE

#### Scenario: JWT interceptor
- **WHEN** API client makes authenticated request
- **THEN** the system automatically includes JWT in Authorization header
- **AND** refreshes token if expired
- **AND** redirects to login on 401 Unauthorized

## MODIFIED Requirements

None - All authentication features are new in Phase 1 (listed under ADDED Requirements)

## REMOVED Requirements

None

## Dependency Map

```mermaid
graph TD
    A[SOC Portal UI] -->|JWT Auth| B[API Service]
    A -->|TLS| B
    A -->|WebSocket for real-time metrics| B
    B -->|Query logs_{tenant_uuid}| C[ClickHouse]
    B -->|CRUD tenants, users, audit logs| D[PostgreSQL]
    A -->|Docker API for service restart| E[Docker Host]
```

## Open Questions

1. **Real-time updates**: Use WebSocket or polling for dashboard metrics?
   - **Recommendation**: Polling (30s interval) for Phase 1, WebSocket for Phase 2

2. **Saved searches storage**: PostgreSQL or browser localStorage?
   - **Recommendation**: PostgreSQL for Phase 1 (syncs across devices), localStorage for caching

3. **Export limits**: Hard cap at 10,000 rows or allow unlimited with warning?
   - **Recommendation**: 10,000 row cap for Phase 1, background job for larger exports in Phase 2
