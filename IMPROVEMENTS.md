# Improvements Roadmap

This document outlines potential improvements and features for Phase 1C and beyond.

## Phase 1C Features

### Dynamic Service Status Monitoring
**Priority:** High  
**Effort:** 1-2 weeks

Implement real-time service health monitoring with automatic discovery of Docker containers.

**Current Behavior:**
- Dashboard shows 8 hardcoded service status cards
- Status is always "operational" (static text)
- No real-time health updates

**Improvement:**

**Backend (api-service):**
- Add Python Docker SDK dependency (`docker` package)
- New endpoint: `GET /api/services/status`
- Query Docker daemon via socket (`/var/run/docker.sock`)
- Filter containers by `com.docker.compose.project=oasis` label
- Extract for each container:
  - Service name (from `com.docker.compose.service` label or container name)
  - Health status (healthy/unhealthy/starting/none)
  - Uptime duration
  - Container state (running/stopped/restarting)
  - Network subnets (DMZ/Internal/Backend)

**Response Format:**
```json
{
  "services": [
    {
      "name": "Internal Gateway",
      "container": "oasis-internal-gateway",
      "status": "healthy",
      "state": "running",
      "uptime_seconds": 7200,
      "networks": ["internal-network", "backend-network"]
    },
    {
      "name": "Ingestion Service",
      "container": "oasis-ingestion-service",
      "status": "none",
      "state": "stopped",
      "uptime_seconds": 0,
      "networks": []
    }
  ]
}
```

**Frontend (soc-portal):**
- Add `useEffect` hook to poll `/api/services/status` every 30 seconds
- Dynamically generate status cards from API response (no hardcoded list)
- Status color coding:
  - **Green**: `status=healthy` and `state=running`
  - **Yellow**: `status=starting` or `state=restarting`
  - **Red**: `status=unhealthy` or `state=stopped/exited`
  - **Gray**: `status=none` (no health check configured)
- Show additional info on hover (uptime, network subnets)

**Benefits:**
- ✅ Automatic discovery: Adding new services to `docker-compose.yml` automatically adds dashboard cards
- ✅ Real health monitoring: Uses Docker's built-in health checks (already configured)
- ✅ No manual updates: Service list stays in sync with actual deployments
- ✅ Network awareness: Can group/badge services by subnet (DMZ/Internal/Backend)
- ✅ Production-ready: Foundation for multi-host monitoring (Phase 3+)

**Future: Multi-Host Support (Phase 3+)**

For distributed deployments across multiple Docker hosts:

**Option 1: Docker Swarm Mode**
- Built-in service discovery across nodes
- Swarm API aggregates health from all workers
- Labels propagate to all service replicas

**Option 2: Kubernetes**
- Labels & selectors: `app=oasis, component=gateway`
- Service discovery via DNS and API server
- Health via liveness/readiness probes

**Option 3: Custom Agent Architecture**
- Deploy lightweight "OASIS Agent" on each Docker host
- Agents query local Docker daemon, report to central API
- Central API aggregates status from all agents
- Works with any container runtime (Docker/Podman/containerd)

**Option 4: Service Mesh (Consul)**
- Each container registers with Consul agent
- Consul provides distributed health checks
- Query Consul API for all services with `project=oasis` tag

**Implementation Notes:**
- Mount Docker socket in api-service container: `/var/run/docker.sock:/var/run/docker.sock:ro`
- Security: Socket is read-only, api-service only queries (no start/stop/delete operations)
- Docker Compose labels are automatically added (no custom labels needed)
- Standard label: `com.docker.compose.project=oasis`

---

## Phase 2 Features

### Customer Portal (Separate Deployment)
**Priority:** High  
**Effort:** 4-6 weeks

Separate Next.js deployment for tenant users to access their own logs without admin features.

**Features:**
- Separate web application at `customer-portal` domain
- Authentication: JWT with tenant-scoped access
- Read-only log viewer (tenant's logs only)
- Saved searches and dashboards
- Export logs to CSV/JSON (limited to 10k rows)
- Account settings (change password, regenerate TOTP)

**Deployment:**
- Deploy in DMZ subnet alongside external gateway
- Shared API service backend with SOC Portal
- Separate build/deployment pipeline
- Same codebase, different feature flags

**Benefits:**
- Tenants can self-service log access
- Reduces load on SOC team
- Potential revenue stream (SaaS model)

---

### Rolling Certificate Restart
**Priority:** Medium  
**Effort:** 1-2 weeks

Implement zero-downtime certificate regeneration using rolling restart strategy.

**Current Behavior:**
- Certificate regeneration restarts all affected containers simultaneously
- Brief downtime (~5-10 seconds) during restart

**Improvement:**
- Multiple gateway instances behind load balancer
- Regenerate certificate for one instance at a time
- Load balancer removes instance from rotation during restart
- No user-facing downtime

**Implementation:**
- Update certificate regeneration API to restart containers one-by-one
- Add `/drain` endpoint to gateway (gracefully finish in-flight requests)
- Load balancer health check integration

---

### Access Audit Report Generation
**Priority:** Medium  
**Effort:** 2-3 weeks

Generate compliance reports from audit logs for SOC 2, ISO 27001, HIPAA.

**Features:**
- Pre-built report templates (SOC 2, ISO 27001, HIPAA)
- Custom date range selection
- Filters: user, tenant, action type
- Export formats: PDF, CSV, JSON
- Scheduled reports (daily, weekly, monthly)
- Email delivery with SMTP integration

**Report Types:**
1. **User Access Report**: Who logged in, from where, when
2. **Configuration Change Report**: What changed, who changed it
3. **Failed Access Attempts**: Brute force detection
4. **Privileged Action Report**: Certificate regeneration, tenant deletion

---

### Separate API Services (Microservices)
**Priority:** Low  
**Effort:** 4-6 weeks

Split monolithic API service into specialized microservices for better scalability.

**Current Architecture:**
- Single API service handles: auth, tenants, logs, certificates, configuration

**Proposed Architecture:**
```
auth-service:       /auth/*         (User authentication, JWT)
tenant-service:     /tenants/*      (Tenant CRUD, API keys)
query-service:      /logs/*         (Log queries, ClickHouse)
config-service:     /certificates/* (Certificates, system config)
```

**Benefits:**
- Independent scaling (scale query-service during high read load)
- Technology diversity (use Go for query-service if needed)
- Fault isolation (auth failure doesn't affect log queries)

**Challenges:**
- Increased operational complexity
- Inter-service communication overhead
- Distributed transaction management

---

### Query Result Caching (Redis)
**Priority:** Medium  
**Effort:** 1-2 weeks

Cache frequent log queries in Redis to reduce ClickHouse load.

**Implementation:**
- Cache key: hash(tenant_id, query_params, time_range)
- TTL: 5 minutes for recent queries (last 24h), 1 hour for older queries
- Invalidation: On new log ingestion (simple), or time-based (Phase 2)

**Example Flow:**
1. User queries logs for last 1 hour
2. API service checks Redis cache
3. **Cache hit**: Return cached results (p95 latency: <50ms)
4. **Cache miss**: Query ClickHouse, cache result, return (p95 latency: <2s)

**Metrics:**
- Cache hit rate: Target >60% for dashboard queries
- Reduced ClickHouse load by 50%+

---

### Real-Time Log Streaming (WebSocket)
**Priority:** Low  
**Effort:** 2-3 weeks

Stream new logs to SOC Portal in real-time without polling.

**Implementation:**
- WebSocket endpoint: `ws://api-service/logs/stream`
- Client subscribes with filters (severity, category, time range)
- Ingestion service publishes new logs to Redis Pub/Sub
- API service subscribes to Redis, forwards to connected WebSocket clients

**Use Case:**
- Live log monitoring dashboard
- Real-time threat detection alerts
- Incident response dashboards

**Challenges:**
- Connection management (scale to 100+ concurrent connections)
- Authentication via WebSocket (JWT in query param)
- Backpressure handling (slow client)

---

### Advanced Retention Policies
**Priority:** Low  
**Effort:** 1-2 weeks

Implement tiered retention with cold storage for compliance.

**Current Behavior:**
- Single retention policy per tenant (e.g., 90 days)
- Data deleted after TTL expires

**Improvement:**
```
Hot Storage (ClickHouse):   Last 30 days   (fast queries)
Warm Storage (ClickHouse):  31-90 days     (compressed, slower)
Cold Storage (S3/MinIO):    91-365 days    (archival, manual restore)
```

**Benefits:**
- Compliance: Retain data for 1+ year without high storage costs
- Cost optimization: S3 storage ~10x cheaper than SSD

**Implementation:**
- ClickHouse `MOVE PARTITION` to different storage tier
- Backup old partitions to S3 via ClickHouse backup tool
- Restore API for cold storage queries (batch job)

---

### External Certificate Import
**Priority:** Medium  
**Effort:** 1 week

Allow importing externally signed certificates (Let's Encrypt, corporate CA).

**Current Behavior:**
- Only self-signed certificates supported

**Improvement:**
- Upload custom certificate PEM + private key via UI
- Validate certificate chain
- Store in PostgreSQL certificates table
- Restart services with new certificate

**Use Cases:**
- Production deployments with Let's Encrypt
- Corporate PKI integration
- Remove browser warnings for SOC Portal

---

### Multi-Factor Authentication (MFA) Enhancements
**Priority:** Medium  
**Effort:** 2-3 weeks

Support additional MFA methods beyond TOTP.

**Current:** TOTP (Time-based One-Time Password) via Google Authenticator

**Add:**
- **WebAuthn/Passkeys**: Hardware keys (YubiKey, Windows Hello)
- **SMS OTP**: Text message codes (via Twilio)
- **Backup codes**: One-time use recovery codes

**Implementation:**
- WebAuthn library (py_webauthn)
- Store credentials in PostgreSQL users table (webauthn_credential JSONB)
- UI for registering/managing MFA devices

---

### Kubernetes Manifests
**Priority:** Low  
**Effort:** 3-4 weeks

Provide production-ready Kubernetes manifests for cloud deployments.

**Includes:**
- Deployments for all services (gateway, ingestion, api, portal)
- StatefulSets for databases (ClickHouse, PostgreSQL)
- Services (ClusterIP, LoadBalancer)
- Ingress for external access
- Helm chart for easy deployment
- Namespace isolation
- Resource limits and requests
- Horizontal Pod Autoscaler (HPA)
- PersistentVolumeClaims for data storage

**Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: external-gateway
  template:
    spec:
      containers:
      - name: gateway
        image: ghcr.io/0xgruber/oasis-gateway:latest
        resources:
          limits:
            memory: 512Mi
            cpu: 500m
```

---

### Multi-Region Deployment
**Priority:** Low  
**Effort:** 6-8 weeks

Support deploying O.A.S.I.S. across multiple geographic regions.

**Architecture:**
```
Region 1 (US-East):
  - Gateways (accept local logs)
  - ClickHouse cluster node 1
  - API service (read local, write local)

Region 2 (EU-West):
  - Gateways (accept local logs)
  - ClickHouse cluster node 2
  - API service (read local, write local)

Shared:
  - PostgreSQL with replication (primary in US-East, replica in EU-West)
  - ClickHouse replication (sync logs across regions)
```

**Benefits:**
- Low latency for global users
- Data residency compliance (GDPR)
- High availability (region failover)

**Challenges:**
- Complex replication setup
- Cross-region network latency
- Data consistency guarantees

---

## Phase 3+ Features (AI Integration)

### Semantic Search with Qdrant
**Priority:** High  
**Effort:** 4-6 weeks

Enable natural language log search using vector embeddings.

**Example Queries:**
- "Show me all failed SSH login attempts from Russia"
- "Find logs related to the Acme Corp breach last week"
- "What happened before the database crash?"

**Implementation:**
- Generate embeddings for logs using Ollama (Llama-3)
- Store in Qdrant vector database
- Vector similarity search for user queries
- Combine with traditional filters (time range, severity)

---

### MCP Server for LLM Integration
**Priority:** High  
**Effort:** 6-8 weeks

Implement Model Context Protocol server for AI-driven log analysis.

**Features:**
- Custom MCP tools: `query_logs`, `fetch_threat_intel`, `analyze_pattern`
- Ollama integration (Llama-3, Mistral, CodeLlama)
- Chat interface in SOC Portal
- Context-aware queries (remember conversation history)

**Example Interaction:**
```
User: "What's the most common error in the last hour?"
AI:   "The most common error is 'Connection timeout' with 1,234 occurrences, 
       primarily affecting API service. Peak at 2:15 PM UTC."

User: "Show me the source IPs"
AI:   "Top source IPs: 192.168.1.10 (450), 10.0.0.5 (320), 172.16.0.8 (210)"
```

---

### Automated Threat Detection (Phase 4)
**Priority:** High  
**Effort:** 8-12 weeks

Use AI to automatically detect security threats in logs.

**Detection Types:**
- Brute force attacks
- SQL injection attempts
- Privilege escalation
- Data exfiltration
- Lateral movement
- Anomalous behavior (ML-based)

**Implementation:**
- Real-time log analysis via MCP server
- Pre-trained detection models (YARA rules, Sigma rules)
- Custom model training on tenant data
- Alert generation with severity scoring
- Integration with alert-service (Phase 4)

---

### Alert Engine (Phase 4)
**Priority:** High  
**Effort:** 6-8 weeks

Generate alerts based on log patterns and AI detections.

**Features:**
- Rule-based alerts (e.g., "if 5 failed logins in 1 minute, alert")
- Anomaly detection alerts (ML-based)
- Alert routing (email, Slack, PagerDuty, webhook)
- Alert escalation (severity-based)
- Alert deduplication (group similar alerts)

---

## Cost Optimization Ideas

### Log Compression Tuning
- Evaluate different ClickHouse compression codecs (LZ4, ZSTD, Delta)
- Target: 15-20x compression ratio (currently 10x)

### Tiered Storage
- Move cold logs to object storage (S3, MinIO)
- Reduce hot storage costs by 70%

### Query Optimization
- Materialized views for common aggregations
- Reduce query latency from 2s → 200ms

### Resource Right-Sizing
- Profile actual memory/CPU usage in production
- Reduce over-provisioned containers
- Target: 30% cost reduction

---

## Security Enhancements

### Zero-Trust Network Architecture
- Mutual TLS for all inter-service communication (currently gateway → ingestion only)
- Service mesh (Istio, Linkerd) for policy enforcement

### Hardware Security Module (HSM) Integration
- Store certificate private keys in HSM (AWS CloudHSM, YubiHSM)
- FIPS 140-2 compliance for sensitive deployments

### Audit Log Immutability
- Write audit logs to append-only storage (WORM)
- Blockchain-backed audit trail (future)

---

## Monitoring & Observability

### Prometheus + Grafana
**Effort:** 2-3 weeks

Deploy monitoring stack for production visibility.

**Metrics:**
- Ingestion rate (EPS per tenant)
- Query latency (p50, p95, p99)
- Error rates (4xx, 5xx)
- Resource usage (CPU, memory, disk)
- Database performance (query time, connection pool)

**Dashboards:**
- System health overview
- Per-tenant metrics
- Security events (failed auth, rate limit hits)
- Capacity planning (disk growth, projected exhaustion)

---

### Distributed Tracing (OpenTelemetry)
**Effort:** 3-4 weeks

Track requests across microservices for performance debugging.

**Example Trace:**
```
Vector Agent → Gateway (5ms) → Ingestion (15ms) → ClickHouse (25ms) → Total: 45ms
```

**Use Cases:**
- Identify bottlenecks (which service is slow?)
- Debug intermittent failures
- Optimize end-to-end latency

---

### Mobile-Friendly SOC Portal
**Priority:** Low  
**Effort:** 2-3 weeks

Implement responsive design for mobile and tablet devices.

**Current Behavior:**
- SOC Portal optimized for desktop browsers (1920x1080+)
- Fixed sidebar layout breaks on mobile
- Tables require horizontal scrolling
- Modals may overflow small screens

**Improvements:**
- Responsive layout with breakpoints (mobile: <768px, tablet: 768-1024px, desktop: >1024px)
- Collapsible sidebar with hamburger menu on mobile
- Touch-friendly UI elements (larger tap targets, swipe gestures)
- Stacked table layouts for mobile (card-based instead of table rows)
- Modals adapt to screen size (full-screen on mobile)
- Optimized cyber theme effects for lower-power mobile devices

**Implementation:**
- Tailwind CSS responsive utilities (sm:, md:, lg:, xl:)
- Mobile-first CSS approach
- Touch event handlers for swipe navigation
- Viewport meta tag configuration
- Progressive Web App (PWA) support (optional)

**Benefits:**
- Security analysts can monitor alerts on mobile devices
- Improved accessibility for tablet users
- Better incident response flexibility (on-the-go access)

---

## Contribution Guidelines

Have ideas for improvements? Submit a proposal:

1. Open GitHub Discussion with proposal
2. Use template: **Problem Statement**, **Proposed Solution**, **Benefits**, **Effort Estimate**
3. Tag with `enhancement` label
4. Community votes on priority
5. Maintainers review and approve

---

## Roadmap Priority Matrix

| Feature | Priority | Effort | Impact | Phase |
|---------|----------|--------|--------|-------|
| Customer Portal | High | 4-6w | High | 2 |
| Semantic Search | High | 4-6w | High | 3 |
| MCP Server | High | 6-8w | High | 3 |
| Query Caching (Redis) | Medium | 1-2w | Medium | 2 |
| Audit Reports | Medium | 2-3w | Medium | 2 |
| Rolling Cert Restart | Medium | 1-2w | Low | 2 |
| K8s Manifests | Low | 3-4w | Medium | 2 |
| Multi-Region | Low | 6-8w | Low | 3+ |
| Mobile-Friendly Portal | Low | 2-3w | Low | 3+ |

**Priority Calculation:**
- High: Critical for production use or major competitive advantage
- Medium: Improves user experience or operational efficiency
- Low: Nice-to-have, limited impact

---

## Get Involved

Join the O.A.S.I.S. community:
- 🐙 GitHub: [github.com/0xgruber/oasis](https://github.com/0xgruber/oasis)
- 💬 Discussions: [GitHub Discussions](https://github.com/0xgruber/oasis/discussions)
- 🐛 Report Bugs: [GitHub Issues](https://github.com/0xgruber/oasis/issues)
- 📧 Email: security@oasis-siem.org
