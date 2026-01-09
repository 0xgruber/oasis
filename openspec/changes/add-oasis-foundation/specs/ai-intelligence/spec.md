## ADDED Requirements

### Requirement: MCP Infrastructure Preparation
The system SHALL include architecture and design documentation for Model Context Protocol (MCP) integration in Phase 3 with support for distributed GPU deployment.

#### Scenario: MCP server design specification
- **WHEN** Phase 3 planning begins
- **THEN** the system provides documented MCP server architecture
- **AND** defines custom tools for database access (tool_query_db, tool_fetch_threat_intel)
- **AND** specifies Ollama integration approach for multiple deployment models

#### Scenario: Distributed GPU architecture
- **WHEN** system architecture is designed
- **THEN** GPU/VRAM services are isolated from core SIEM services
- **AND** supports deployment on separate container, instance, or bare-metal hardware
- **AND** documents API-based communication between core and GPU services
- **AND** includes graceful degradation when GPU services unavailable

#### Scenario: Ollama deployment options
- **WHEN** Docker Compose configuration is created
- **THEN** the system includes multiple Docker Compose profiles
- **AND** provides `default` profile (no GPU services)
- **AND** provides `gpu-dev` profile (local GPU with passthrough)
- **AND** provides `gpu-remote` profile (external GPU service endpoint)
- **AND** documents bare-metal deployment configuration

### Requirement: Vector Embedding Pipeline Design
The system SHALL document the architecture for future semantic search and embedding generation.

#### Scenario: Embedding generation workflow
- **WHEN** Phase 3 implementation begins
- **THEN** the system provides documented workflow for log embedding generation
- **AND** specifies batch processing for historical logs
- **AND** defines real-time embedding for new logs

#### Scenario: Qdrant integration readiness
- **WHEN** Qdrant service is activated
- **THEN** the system can create collections with 768-dimension vectors
- **AND** supports metadata filtering on event_id, timestamp, severity
- **AND** provides API endpoints for similarity search

### Requirement: AI-First API Design
The system SHALL design REST APIs with future natural language query support.

#### Scenario: Query endpoint extensibility
- **WHEN** a standard log query is executed via `/api/v1/logs/search`
- **THEN** the API returns structured results
- **AND** the endpoint design supports future addition of `/api/v1/logs/nlp-search`
- **AND** maintains consistent response schemas

#### Scenario: MCP tool compatibility
- **WHEN** API endpoints are designed
- **THEN** endpoints accept parameters compatible with MCP tool schemas
- **AND** provide JSON responses parseable by LLMs
- **AND** include error messages suitable for LLM interpretation

### Requirement: Privacy and Local Processing with Multi-Tenancy
The system SHALL ensure all AI processing occurs locally without external API calls, with support for distributed on-premise deployment and strict tenant data isolation.

#### Scenario: No external LLM dependencies
- **WHEN** the system is deployed
- **THEN** no API keys for OpenAI, Anthropic, or other cloud LLM providers are required
- **AND** all configuration uses local or on-premise Ollama endpoints
- **AND** logs never leave the local/on-premise infrastructure

#### Scenario: Model management
- **WHEN** LLM models are deployed (Phase 3)
- **THEN** models are stored locally in Docker volumes or on dedicated GPU hardware
- **AND** no model data is transmitted to external services
- **AND** model updates are manual and auditable

#### Scenario: Distributed on-premise deployment
- **WHEN** GPU services are deployed on separate hardware
- **THEN** communication uses secure internal network protocols (mutual TLS)
- **AND** API keys authenticate inter-service communication
- **AND** no data traverses public internet

#### Scenario: Tenant-isolated AI queries (Phase 3)
- **WHEN** a user asks an AI question about logs via MCP/LLM
- **THEN** the MCP server extracts tenant_id from user's JWT
- **AND** scopes all database tool queries to that tenant's logs_{tenant_uuid} table
- **AND** never returns data from other tenants
- **AND** logs AI query to audit_logs with tenant_id
