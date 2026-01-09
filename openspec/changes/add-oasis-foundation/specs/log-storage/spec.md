## ADDED Requirements

### Requirement: ClickHouse Log Storage
The system SHALL store security logs in ClickHouse with optimized columnar compression and partitioning.

#### Scenario: Log insertion
- **WHEN** normalized logs are written to ClickHouse
- **THEN** the system inserts into the `logs` table
- **AND** partitions data by month (YYYYMM)
- **AND** orders by timestamp, severity, and category for query optimization

#### Scenario: Compression and storage efficiency
- **WHEN** logs are stored in ClickHouse
- **THEN** the system achieves at least 10x compression ratio
- **AND** monitors disk usage to stay within available storage

#### Scenario: Time-based retention
- **WHEN** logs exceed the configured retention period (default 90 days)
- **THEN** ClickHouse automatically deletes old partitions via TTL
- **AND** logs retention policy execution

### Requirement: PostgreSQL Application Data
The system SHALL store application metadata, user accounts, and configuration in PostgreSQL.

#### Scenario: User account storage
- **WHEN** a new user is created
- **THEN** the system stores user credentials (hashed), email, and role in PostgreSQL
- **AND** enforces unique constraints on username and email

#### Scenario: Saved search persistence
- **WHEN** a user saves a search query
- **THEN** the system stores the query string, name, and filters in PostgreSQL
- **AND** associates it with the user's account

#### Scenario: System configuration storage
- **WHEN** system settings are updated (retention policy, rate limits)
- **THEN** the system stores configuration in PostgreSQL `system_config` table
- **AND** validates configuration before applying

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

### Requirement: Query Performance
The system SHALL optimize queries for common log search patterns.

#### Scenario: Time-range queries
- **WHEN** a user queries logs for a specific time range (e.g., last 24 hours)
- **THEN** ClickHouse leverages partition pruning
- **AND** returns results with p95 latency under 2 seconds

#### Scenario: Filtered queries
- **WHEN** a user filters logs by severity, category, or IP address
- **THEN** ClickHouse uses the ORDER BY index for efficient filtering
- **AND** returns up to 10,000 results per query

#### Scenario: Aggregation queries
- **WHEN** a user requests aggregated statistics (e.g., count by severity)
- **THEN** ClickHouse performs aggregation using columnar storage
- **AND** returns results within 1 second for 1M+ rows

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
