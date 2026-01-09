## ADDED Requirements

### Requirement: ClickHouse Multi-Tenant Table Isolation
The system SHALL store logs in tenant-specific tables to enforce strict data isolation.

#### Scenario: Tenant table naming
- **WHEN** a new tenant is created with UUID 550e8400-e29b-41d4-a716-446655440000
- **THEN** the system creates ClickHouse table `logs_550e8400_e29b_41d4_a716_446655440000`
- **AND** table follows standard schema (timestamp, event_id, category, severity, raw_log, metadata)
- **AND** table uses MergeTree engine with partitioning by month

#### Scenario: Auto-create "Internal" tenant table
- **WHEN** O.A.S.I.S. starts for the first time
- **THEN** the system creates tenant "Internal" in PostgreSQL
- **AND** creates ClickHouse table `logs_{internal_tenant_uuid}`
- **AND** sets default retention policy (90 days)

#### Scenario: Tenant table creation on first ingestion
- **WHEN** ingestion-service receives logs for a tenant without a ClickHouse table
- **THEN** the system automatically creates `logs_{tenant_uuid}` table
- **AND** applies tenant's configured retention policy from PostgreSQL
- **AND** creates monthly partitions starting from current month

#### Scenario: Log insertion to tenant-specific table
- **WHEN** normalized logs are written for tenant "Acme Corp"
- **THEN** the system inserts into `logs_{acme_tenant_uuid}` table only
- **AND** never writes to other tenant tables (enforced at application layer)
- **AND** partitions data by month (YYYYMM)
- **AND** orders by timestamp, severity, and category for query optimization

#### Scenario: Compression and storage efficiency
- **WHEN** logs are stored in ClickHouse tenant tables
- **THEN** the system achieves at least 10x compression ratio per table
- **AND** monitors disk usage per tenant for quota enforcement (Phase 2)

#### Scenario: Per-tenant retention policy
- **WHEN** tenant "Acme Corp" has custom retention policy (180 days)
- **THEN** ClickHouse applies TTL `timestamp + INTERVAL 180 DAY` to that tenant's table
- **AND** automatically deletes expired partitions
- **AND** logs retention policy execution per tenant

#### Scenario: Tenant retention policy update
- **WHEN** admin updates tenant retention policy from 90 to 180 days
- **THEN** the system alters ClickHouse table TTL clause
- **AND** applies new policy to future data (existing data retains old TTL)

#### Scenario: Global retention policy default
- **WHEN** a new tenant is created without specifying retention
- **THEN** the system applies global default retention policy (90 days)
- **AND** stores policy in PostgreSQL tenants.retention_days column

### Requirement: PostgreSQL Application Data
The system SHALL store application metadata, tenants, users, API keys, certificates, audit logs, and system configuration in PostgreSQL.

#### Scenario: Tenant storage
- **WHEN** a new tenant "Acme Corp" is created
- **THEN** the system stores tenant in PostgreSQL tenants table with UUID, name, retention_days, rate_limit_eps, is_active
- **AND** enforces unique constraint on tenant name
- **AND** generates tenant UUID for ClickHouse table naming

#### Scenario: API key storage
- **WHEN** a tenant is created or API key is regenerated
- **THEN** the system generates random API key (e.g., "oasis_pk_abc123...")
- **AND** stores bcrypt hash of key in PostgreSQL api_keys table
- **AND** stores key prefix (first 8 chars) for display in UI
- **AND** enforces 1:1 relationship (one API key per tenant)

#### Scenario: User account storage
- **WHEN** a new user is created
- **THEN** the system stores username, bcrypt password hash, email, role, tenant_id in PostgreSQL users table
- **AND** enforces unique constraints on username and email
- **AND** stores TOTP secret (base32-encoded) for two-factor authentication

#### Scenario: Certificate storage
- **WHEN** system generates or regenerates TLS certificates
- **THEN** the system stores certificate name, PEM-encoded certificate, private key, expiration date in PostgreSQL certificates table
- **AND** associates certificate regeneration with admin user (regenerated_by column)

#### Scenario: Audit log storage
- **WHEN** a user performs CRUD operation or sensitive action
- **THEN** the system writes audit log to PostgreSQL audit_logs table with timestamp, user_id, tenant_id, action, resource_type, resource_id, IP, user_agent, metadata
- **AND** retains audit logs for 1 year minimum (configurable)

#### Scenario: System configuration storage
- **WHEN** system settings are updated (SMTP server, database connections, Docker limits)
- **THEN** the system stores configuration in PostgreSQL system_config table (key-value pairs)
- **AND** validates configuration before applying
- **AND** logs who updated config (updated_by references users.id)

### Requirement: Qdrant Vector Storage Preparation
The system SHALL include Qdrant configuration for future semantic search capabilities.

#### Scenario: Qdrant service availability
- **WHEN** the Docker Compose environment starts
- **THEN** Qdrant container is running and healthy
- **AND** exposes API on port 6333
- **AND** persists data to named volume

#### Scenario: Collection schema readiness
- **WHEN** Phase 3 AI integration begins
- **THEN** the system can create `log_embeddings` collection
- **AND** configure vector dimension to 768 (Llama-3 embedding size)

### Requirement: Database Authentication
The system SHALL enforce authentication for all service-to-database connections using dedicated user accounts.

#### Scenario: ClickHouse ingestion user
- **WHEN** ingestion-service connects to ClickHouse
- **THEN** the system authenticates with dedicated `ingestion_user` account
- **AND** grants only INSERT permission on tenant tables (logs_*)
- **AND** denies SELECT, ALTER, DROP permissions (principle of least privilege)

#### Scenario: ClickHouse API user
- **WHEN** API service connects to ClickHouse for queries
- **THEN** the system authenticates with dedicated `api_user` account
- **AND** grants only SELECT permission on tenant tables
- **AND** denies INSERT, ALTER, DROP permissions

#### Scenario: PostgreSQL service users
- **WHEN** backend services connect to PostgreSQL
- **THEN** the system uses service-specific accounts (ingestion_pg_user, api_pg_user)
- **AND** grants role-based permissions (ingestion: INSERT audit_logs, api: SELECT/INSERT/UPDATE all tables)

#### Scenario: Database authentication failure
- **WHEN** a service attempts to connect with invalid credentials
- **THEN** the database rejects the connection
- **AND** service logs authentication failure
- **AND** returns HTTP 500 Internal Server Error to client (do not expose credentials error)

### Requirement: Database Connection Management
The system SHALL manage database connections efficiently within memory constraints.

#### Scenario: Connection pooling
- **WHEN** the API service connects to databases
- **THEN** the system uses connection pooling (max 20 connections per database)
- **AND** reuses connections for multiple queries
- **AND** times out idle connections after 5 minutes

#### Scenario: Connection failure handling
- **WHEN** a database connection fails
- **THEN** the system retries with exponential backoff (max 3 attempts)
- **AND** logs the failure for monitoring
- **AND** returns appropriate error to client

### Requirement: Query Performance with Tenant Isolation
The system SHALL optimize queries for common log search patterns while enforcing tenant isolation.

#### Scenario: Tenant-scoped time-range queries
- **WHEN** a user queries logs for last 24 hours for their tenant
- **THEN** API service queries only `logs_{tenant_uuid}` table (extracted from JWT)
- **AND** ClickHouse leverages partition pruning for date range
- **AND** returns results with p95 latency under 2 seconds

#### Scenario: Filtered queries with tenant isolation
- **WHEN** a user filters logs by severity, category, or IP address
- **THEN** API service enforces tenant isolation by querying tenant-specific table
- **AND** ClickHouse uses the ORDER BY index for efficient filtering
- **AND** returns up to 10,000 results per query

#### Scenario: Aggregation queries per tenant
- **WHEN** a user requests aggregated statistics (e.g., count by severity) for their tenant
- **THEN** ClickHouse performs aggregation on tenant-specific table using columnar storage
- **AND** returns results within 1 second for 1M+ rows

#### Scenario: Cross-tenant query prevention
- **WHEN** a malicious user attempts to query another tenant's table (SQL injection or direct table name)
- **THEN** API service validates tenant_id from JWT matches table name
- **AND** rejects query with HTTP 403 Forbidden if mismatch detected
- **AND** logs security violation to audit_logs table

### Requirement: Data Integrity and Backup
The system SHALL ensure data durability and provide backup mechanisms.

#### Scenario: Write confirmation
- **WHEN** a batch write to ClickHouse completes
- **THEN** the system confirms write success
- **AND** does not acknowledge ingestion until data is persisted

#### Scenario: Volume persistence
- **WHEN** Docker containers are stopped and restarted
- **THEN** all database data persists via named volumes
- **AND** no data loss occurs
