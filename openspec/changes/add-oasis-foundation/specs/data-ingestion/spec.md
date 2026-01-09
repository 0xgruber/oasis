## ADDED Requirements

### Requirement: Syslog-ng Integration
The system SHALL integrate syslog-ng as the primary log collection agent for receiving and processing logs from network sources.

#### Scenario: Syslog-ng deployment
- **WHEN** the Docker Compose environment starts
- **THEN** syslog-ng container is running and healthy
- **AND** listens on UDP/TCP port 514 for standard syslog
- **AND** listens on TCP port 6514 for TLS-encrypted syslog

#### Scenario: Log reception and parsing
- **WHEN** syslog-ng receives a log message
- **THEN** syslog-ng parses the message according to configured templates
- **AND** performs initial filtering and enrichment
- **AND** forwards structured output to O.A.S.I.S. ingestion API

#### Scenario: Multiple log source support
- **WHEN** syslog-ng is configured with multiple sources
- **THEN** syslog-ng handles syslog, file inputs, network streams
- **AND** applies source-specific parsing rules
- **AND** tags logs with source identifier for downstream processing

### Requirement: Log Ingestion Endpoints
The system SHALL provide HTTP endpoints for receiving log data from syslog-ng and other sources.

#### Scenario: HTTP JSON log ingestion from syslog-ng
- **WHEN** syslog-ng sends a POST request to `/api/v1/ingest` with JSON log data
- **THEN** the system returns HTTP 202 Accepted
- **AND** the log is queued for processing

#### Scenario: Batch ingestion
- **WHEN** a client sends multiple logs in a single POST request (JSON array)
- **THEN** the system accepts the batch
- **AND** returns HTTP 202 Accepted
- **AND** processes logs asynchronously

#### Scenario: Invalid log format
- **WHEN** a client sends malformed or invalid log data
- **THEN** the system returns HTTP 400 Bad Request
- **AND** includes a descriptive error message

### Requirement: OCSF Normalization
The system SHALL normalize all ingested logs to the Open Cybersecurity Schema Framework (OCSF) standard.

#### Scenario: Successful normalization
- **WHEN** a raw log is processed by the normalization engine
- **THEN** the system maps fields to OCSF category and class
- **AND** preserves the original raw log in the `raw_log` field
- **AND** extracts common fields (timestamp, severity, source IP, destination IP, user)

#### Scenario: Normalization failure fallback
- **WHEN** a log cannot be normalized to OCSF
- **THEN** the system stores the raw log with category "Unknown"
- **AND** logs a warning for monitoring
- **AND** does not reject the ingestion

### Requirement: Data Routing
The system SHALL route normalized logs to appropriate storage backends based on data type.

#### Scenario: Route to ClickHouse
- **WHEN** a log is successfully normalized
- **THEN** the system writes the normalized log to ClickHouse
- **AND** includes timestamp, event_id, category, class, severity, and metadata

#### Scenario: Batch write optimization
- **WHEN** the ingestion buffer reaches 1000 logs or 5 seconds elapsed
- **THEN** the system performs a batch insert to ClickHouse
- **AND** confirms write success before clearing the buffer

### Requirement: Rate Limiting and Back-pressure
The system SHALL handle ingestion bursts without data loss or service degradation.

#### Scenario: Normal ingestion load
- **WHEN** the ingestion rate is below 10,000 events per second
- **THEN** all logs are processed with p99 latency under 100ms

#### Scenario: Burst traffic handling
- **WHEN** the ingestion rate exceeds 10,000 events per second
- **THEN** the system buffers logs in memory up to 50MB
- **AND** returns HTTP 503 Service Unavailable if buffer is full
- **AND** includes Retry-After header with suggested wait time

### Requirement: Input Validation
The system SHALL validate all ingested logs for security and data integrity.

#### Scenario: Field size limits
- **WHEN** a log field exceeds maximum size (e.g., 1MB per field)
- **THEN** the system truncates the field
- **AND** adds a metadata flag indicating truncation

#### Scenario: Malicious input detection
- **WHEN** a log contains suspicious patterns (SQL injection, script tags)
- **THEN** the system sanitizes the input
- **AND** stores the original in a quarantine field for analysis
