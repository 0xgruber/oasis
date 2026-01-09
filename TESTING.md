# O.A.S.I.S. Phase 1A Testing Checklist

This guide documents the exact steps required to validate the Phase 1A infrastructure (gateways, ingestion service, ClickHouse, API service, and SOC portal). Follow the sections in order to reproduce the test run that verified end-to-end log ingestion on January 8, 2026.

---

## 1. Prerequisites

- Docker + Docker Compose installed
- Local ports 3000, 8000, 8443, 8444, 15432, 8123, 9000, 6333 free
- At least 16 GB RAM available
- `.env` file populated with the following minimum values:
  ```bash
  POSTGRES_ADMIN_PASSWORD=changeme
  CLICKHOUSE_ADMIN_PASSWORD=changeme
  JWT_SECRET=super-secret-jwt-key
  ```
- Recommended but optional: run `docker system prune` before starting to ensure clean volumes

---

## 2. Start the Stack

1. Build/start all services:
   ```bash
   docker compose down -v   # optional full reset
   docker compose up -d
   ```
2. Wait ~2 minutes, then confirm container health:
   ```bash
   docker compose ps
   ```
   Expected status table (all Healthy): `api-service`, `external-gateway`, `internal-gateway`, `ingestion-service`, `clickhouse`, `postgresql`, `soc-portal`, `qdrant`.

3. Spot-check health endpoints:
   ```bash
   curl http://localhost:8000/health       # API service
   curl http://localhost:8443/health       # External gateway
   curl http://localhost:8444/health       # Internal gateway
   curl http://localhost:8080/health       # Ingestion service
   curl http://localhost:3000              # SOC portal (should return HTML)
   curl http://localhost:6333/healthz      # Qdrant
   ```

---

## 3. Seed Authentication Data

The dev database already contains a root tenant (`ffffffff-ffff-ffff-ffff-ffffffffffff`) with a `super_admin` user and API key. Validate the seed data:

```bash
# Verify admin account
docker compose exec postgresql psql -U admin -d oasis \
  -c "SELECT username, role FROM users WHERE username='admin';"

# Verify API key
docker compose exec postgresql psql -U admin -d oasis \
  -c "SELECT prefix, description FROM api_keys;"
```

If you need to regenerate the admin password hash for any reason:
```bash
docker compose exec api-service /app/.venv/bin/python3 - <<'EOF'
import bcrypt
print(bcrypt.hashpw(b'Admin123!', bcrypt.gensalt()).decode())
EOF
# Update users table with the new hash.
```

---

## 4. Send Verification Logs

Use the external gateway (`http://localhost:8443`) and the known test API key `oasis-test-key-12345678` to send a diverse batch of logs mirroring the January 8 session.

```bash
curl -X POST http://localhost:8443/api/v1/ingest \
  -H "Authorization: oasis-test-key-12345678" \
  -H "Content-Type: application/json" \
  -d '{
        "logs": [
          {"timestamp":"2026-01-08T23:24:00Z","severity":"debug","message":"API request processed","source":"api-gateway","metadata":{"application":"gateway","host":"gateway-01","endpoint":"/api/v1/users","method":"GET","response_time_ms":42}},
          {"timestamp":"2026-01-08T23:23:00Z","severity":"info","message":"User login successful","source":"auth-service","metadata":{"application":"authentication","host":"auth-server-01","username":"john.doe","ip_address":"10.0.1.50"}},
          {"timestamp":"2026-01-08T23:22:00Z","severity":"critical","message":"Security alert: Multiple failed login attempts","source":"auth-service","metadata":{"application":"authentication","host":"auth-server-01","username":"admin","ip_address":"192.168.1.100","attempts":10}},
          {"timestamp":"2026-01-08T23:21:00Z","severity":"error","message":"Failed to connect to database","source":"webapp","metadata":{"application":"customer-portal","host":"app-server-02","error_code":"CONN_TIMEOUT"}},
          {"timestamp":"2026-01-08T23:20:00Z","severity":"warning","message":"High memory usage detected","source":"monitoring-agent","metadata":{"application":"system-monitor","host":"web-server-01","memory_percent":85.5}},
          {"timestamp":"2026-01-08T23:15:00Z","severity":"info","message":"\uD83C\uDF89 FIRST SUCCESSFUL O.A.S.I.S. LOG!","source":"test-client","metadata":{"application":"oasis-test-app","host":"test-server-01"}}
        ]
      }'
```
Expected response:
```json
{"accepted": 6, "rejected": 0, "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff"}
```

---

## 5. Verify ClickHouse Storage

Run the following query to confirm the logs are present and normalized correctly (severity mapping now supports debug, info, warning, error, critical, fatal, etc.):

```bash
docker exec oasis-clickhouse clickhouse-client --query "\
  SELECT timestamp, severity_id, JSONExtractString(raw_log, 'message') AS message \
  FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff \
  ORDER BY timestamp DESC LIMIT 6 FORMAT Pretty"
```
Example output:
```
┏─────────────────────────┳━━━━━━━━━━━━━┳────────────────────────────────────────────────────────────────────────────┓
┃ timestamp               ┃ severity_id ┃ message                                                                     ┃
┡─────────────────────────╇━━━━━━━━━━━━━╇────────────────────────────────────────────────────────────────────────────┩
│ 2026-01-08 23:24:00.000 │           1 │ API request processed                                                       │
│ 2026-01-08 23:23:00.000 │           1 │ User login successful                                                       │
│ 2026-01-08 23:22:00.000 │           5 │ Security alert: Multiple failed login attempts                              │
│ 2026-01-08 23:21:00.000 │           4 │ Failed to connect to database                                               │
│ 2026-01-08 23:20:00.000 │           3 │ High memory usage detected                                                  │
│ 2026-01-08 23:15:00.000 │           1 │ 🎉 FIRST SUCCESSFUL O.A.S.I.S. LOG!                                         │
└─────────────────────────┴─────────────┴────────────────────────────────────────────────────────────────────────────┘
```

Additional verification:
```bash
# Count rows
docker exec oasis-clickhouse clickhouse-client --query "SELECT count() FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff"
```

---

## 6. Test API Service (JWT + /logs)

1. Authenticate as admin:
   ```bash
   curl -X POST http://localhost:8000/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"Admin123!"}'
   ```
   Expected response:
   ```json
   {
     "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
     "token_type": "bearer",
     "user_id": "94d151bc-3428-49c2-a203-e4e321a427c7",
     "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
     "role": "super_admin"
   }
   ```

2. Query logs with the returned token:
   ```bash
   TOKEN="<access_token>"
   curl http://localhost:8000/logs?limit=10 \
     -H "Authorization: Bearer $TOKEN" \
     -s | python3 -m json.tool
   ```
   Expected JSON payload containing the 6 logs, total count, and tenant isolation enforced.

---

## 7. Validate SOC Portal

1. Navigate to http://localhost:3000
2. Login with admin / Admin123!
3. Confirm dashboard renders service status cards and shows log count > 0 in the header
4. Open `Logs` page → click `Refresh`
   - Table should display the same 6 entries as the API response
   - Severity colors: Debug (gray), Info (blue), Warning (yellow), Error (red), Critical (dark red)
5. Click on a row to open the detail modal and verify the OCSF JSON block renders for each log
6. Logout via the sidebar button and ensure you return to `/login`

> Note: Phase 1A focuses on backend verification. The SOC portal currently displays raw ClickHouse fields; full OCSF rendering and pagination polish is deferred to Phase 1B.

---

## 8. Troubleshooting Reference

| Symptom | Checks |
| --- | --- |
| `docker compose ps` shows unhealthy service | `docker logs <service>`; ensure `.env` matches container env |
| Login returns 401 | Confirm admin hash in PostgreSQL; see Section 3 for regeneration command |
| `/logs` returns zero rows | Verify ingestion service logs (`docker logs oasis-ingestion-service`) and ClickHouse table name (tenant-specific) |
| Qdrant unhealthy | Ensure curl installed inside container (already handled) and `http://localhost:6333/healthz` responds |
| SOC portal blank | `docker logs oasis-soc-portal` for Next.js errors, ensure API base URL env var is `http://api-service:8000` inside docker |

---

## 9. Success Criteria Summary

Phase 1A validation is complete when:
- [x] All containers report `healthy` (see Section 2)
- [x] Authentication works (Section 6)
- [x] External gateway accepts logs and ingestion service writes to ClickHouse (Section 4 + 5)
- [x] API `/logs` endpoint returns tenant-scoped data (Section 6)
- [x] SOC portal displays the ingested logs (Section 7)

Document the results of each run (timestamp, git commit SHA, any deviations). The January 8 session corresponds to commit `d7bcdee` plus the follow-up fixes on this branch.

---

## 10. Phase 1B Testing Checklist

Phase 1B extends Phase 1A with enhanced schema alignment, remote access support, and backward-compatible schema migrations.

### 10.1. Prerequisites

All Phase 1A prerequisites plus:
- SOC Portal accessible via Tailscale or remote network (optional, for remote access testing)
- Phase 1B code changes applied (see git commit for this phase)

### 10.2. Verify Enhanced ClickHouse Schema

Phase 1B adds `uuid`, `message`, and `ingested_at` columns to the logs table. Verify the schema includes all required fields:

```bash
docker exec oasis-clickhouse clickhouse-client --query "\
  DESCRIBE TABLE oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff FORMAT Pretty"
```

Expected columns (14 total):
- `uuid` (UUID) - Auto-generated unique identifier
- `timestamp` (DateTime64(3)) - Log event timestamp
- `tenant_id` (UUID) - Tenant isolation
- `raw_log` (String) - Original log payload
- `message` (String) - Extracted message field
- `ocsf` (Object('json')) - Full OCSF normalized data
- `source_ip` (IPv4) - Source IP address
- `destination_ip` (IPv4) - Destination IP address
- `severity_id` (UInt8) - OCSF severity (1=info, 3=warning, 4=error, 5=critical)
- `category_uid` (UInt16) - OCSF category
- `class_uid` (UInt16) - OCSF class
- `activity_id` (UInt8) - OCSF activity
- `status_id` (UInt8) - OCSF status
- `ingested_at` (DateTime64(3)) - Ingestion timestamp

### 10.3. Test Enhanced Log Ingestion

Send logs with explicit `message` fields to verify extraction works:

```bash
curl -X POST http://localhost:8443/api/v1/ingest \
  -H "Authorization: Bearer oasis-test-key-12345678" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [
      {
        "timestamp": "2026-01-09T22:00:00Z",
        "severity": "info",
        "message": "Phase 1B test: Application started",
        "source": "web-app",
        "metadata": {"version": "2.0.0"}
      },
      {
        "timestamp": "2026-01-09T22:01:00Z",
        "severity": "warning",
        "message": "Phase 1B test: Memory threshold exceeded",
        "source": "monitoring",
        "metadata": {"memory_mb": 1900}
      },
      {
        "timestamp": "2026-01-09T22:02:00Z",
        "severity": "error",
        "message": "Phase 1B test: Database connection failed",
        "source": "database-client",
        "metadata": {"timeout_ms": 5000}
      }
    ]
  }'
```

Expected response:
```json
{"accepted": 3, "rejected": 0, "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff"}
```

### 10.4. Verify Storage with New Schema

Confirm logs are stored with all new fields populated:

```bash
docker exec oasis-clickhouse clickhouse-client --query "\
  SELECT uuid, timestamp, severity_id, message, ingested_at \
  FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff \
  WHERE message LIKE 'Phase 1B test:%' \
  ORDER BY timestamp DESC FORMAT Pretty"
```

Expected output should show:
- Unique UUIDs for each log
- Extracted `message` field populated correctly
- `ingested_at` timestamp (different from log `timestamp`)

### 10.5. Test API Response Schema Alignment

Phase 1B aligns the API response with the frontend `LogEntry` interface. Verify all required fields are present:

```bash
# Authenticate
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!"}' | jq -r .access_token)

# Query logs and check schema
curl -s "http://localhost:8000/logs?limit=3" \
  -H "Authorization: Bearer $TOKEN" | jq '.logs[0] | keys'
```

Expected keys in response (10 fields):
```json
[
  "category_uid",
  "class_uid",
  "ingested_at",
  "message",
  "ocsf",
  "raw_log",
  "severity_id",
  "tenant_id",
  "timestamp",
  "uuid"
]
```

Verify data types:
```bash
curl -s "http://localhost:8000/logs?limit=1" \
  -H "Authorization: Bearer $TOKEN" | jq '.logs[0] | {
    uuid: .uuid | type,
    timestamp: .timestamp | type,
    severity_id: .severity_id | type,
    message: .message | type,
    ocsf: .ocsf | type,
    ingested_at: .ingested_at | type
  }'
```

Expected types:
- `uuid`: "string"
- `timestamp`: "number" (milliseconds)
- `severity_id`: "number"
- `message`: "string"
- `ocsf`: "object"
- `ingested_at`: "number" (milliseconds)

### 10.6. Test Remote Access (Same-Origin Proxy Pattern)

Phase 1B implements a reverse proxy pattern for remote access without CORS issues.

**From Remote Machine (via Tailscale):**

1. Navigate to `http://<tailscale-ip>:3000`
2. Login with `admin / Admin123!`
3. Open Browser DevTools → Network tab
4. Navigate to Logs page
5. Verify API calls go to `/api/logs` (same origin, not `localhost:8000`)
6. Confirm logs load successfully

**From Local Machine:**

1. Navigate to `http://localhost:3000`
2. Same verification as above
3. Confirm both local and remote access work identically

### 10.7. Validate SOC Portal UI (Phase 1B)

Enhanced UI validation for Phase 1B features:

1. **Logs Page Display:**
   - Navigate to Logs page
   - Verify table shows logs with proper formatting
   - Confirm severity badges display with correct colors
   - Check timestamps are human-readable (not raw milliseconds)

2. **Log Detail Modal:**
   - Click "View" on any log
   - Verify modal opens with complete log details
   - Confirm UUID is displayed
   - Check `message` field is prominently shown
   - Verify OCSF JSON block renders properly
   - Confirm `ingested_at` timestamp is visible

3. **Navigation:**
   - Click Analytics → Should show "Coming Soon" placeholder
   - Click Alerts → Should show "Coming Soon" placeholder
   - Click Settings → Should show "Coming Soon" placeholder
   - All pages should load without 404 errors

### 10.8. Test Backward Compatibility

Phase 1B includes schema migration logic. Test that the API handles both old and new schemas:

```bash
# Check if migration added columns to existing tables
docker exec oasis-clickhouse clickhouse-client --query "\
  SELECT name FROM system.columns \
  WHERE database = 'oasis' \
  AND table = 'logs_ffffffff_ffff_ffff_ffff_ffffffffffff' \
  AND name IN ('uuid', 'message', 'ingested_at') \
  FORMAT Pretty"
```

All three columns should be present, confirming automatic migration.

### 10.9. Phase 1B Success Criteria

Phase 1B validation is complete when:
- [x] ClickHouse schema includes all 14 columns (uuid, message, ingested_at added)
- [x] Log ingestion extracts and stores `message` field correctly
- [x] API response matches frontend `LogEntry` interface (10 fields with correct types)
- [x] Timestamps are returned as milliseconds (JavaScript-compatible)
- [x] SOC Portal accessible via both local and remote networks
- [x] Logs display correctly in UI with all new fields
- [x] Log detail modal shows complete OCSF data
- [x] Placeholder pages load without 404 errors
- [x] Backward compatibility confirmed (migration works on existing tables)

---

## 11. Next Steps (Phase 1C Targets)

1. Add tenant-aware API key management endpoints (`POST /api-keys`, `GET /api-keys`, `DELETE /api-keys/:id`)
2. Implement API key management UI in Settings page
3. Re-enable mTLS between gateways and ingestion service
4. Add filtering and search to Logs page (by severity, time range, message text)
5. Expand test coverage (unit tests for normalizer, integration tests for schema compatibility)

This document should be updated whenever the testing flow changes. Commit the new version along with any infrastructure modifications so future runs remain reproducible.
