# Vector Agent Deployment - Testing Guide

## Status: Phase 2 Complete - Ready for Integration Testing

### What's Working

✅ **Database Schema Applied**
- `agents` table created with all columns and indexes
- `upsert_agent()` function working correctly
- `mark_inactive_agents()` function ready

✅ **Agent Registration API**
- `POST /api/v1/agents/register` - Creates/updates agents
- `GET /api/v1/agents` - Lists agents (with active_only filter)
- Authentication via Bearer token working
- IP address tracking working
- Metadata storage (JSONB) working

✅ **Deployment Scripts Created**
- Linux: `scripts/deploy-vector.sh` (bash)
- Windows: `scripts/deploy-vector.ps1` (PowerShell)
- Cleanup scripts for both platforms

✅ **Configuration Examples**
- Linux: `VECTOR_EXAMPLES/linux-systemd-production.toml`
- Windows: `VECTOR_EXAMPLES/windows-event-log-production.yaml`

---

## Tested Functionality

### Agent Registration API Tests

```bash
# Test 1: Register new Linux agent
curl -X POST https://192.168.5.32:8444/api/v1/agents/register \
  --cacert infrastructure/certs-new/ca/oasis-ca.pem \
  -H "Authorization: Bearer oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo" \
  -H "Content-Type: application/json" \
  -d '{
    "hostname":"test-agent-1",
    "agent_type":"vector",
    "os_type":"Linux",
    "os_version":"Ubuntu 22.04",
    "agent_version":"0.43.0",
    "metadata":{"datacenter":"test","environment":"dev"}
  }'

# Response: 201 Created
{
  "agent_id": "fea821ce-cd47-449b-90b2-63bb8c8adf0f",
  "status": "registered",
  "message": "Agent 'test-agent-1' registered successfully"
}

# Test 2: Register Windows agent
curl -X POST https://192.168.5.32:8444/api/v1/agents/register \
  --cacert infrastructure/certs-new/ca/oasis-ca.pem \
  -H "Authorization: Bearer oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo" \
  -H "Content-Type: application/json" \
  -d '{
    "hostname":"test-agent-2",
    "agent_type":"vector",
    "os_type":"Windows",
    "os_version":"Windows Server 2022",
    "agent_version":"0.43.0"
  }'

# Response: 201 Created
{
  "agent_id": "5e32aef1-dd56-4995-b2dd-da696ecb33a6",
  "status": "registered",
  "message": "Agent 'test-agent-2' registered successfully"
}

# Test 3: Update existing agent (upsert test)
curl -X POST https://192.168.5.32:8444/api/v1/agents/register \
  --cacert infrastructure/certs-new/ca/oasis-ca.pem \
  -H "Authorization: Bearer oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo" \
  -H "Content-Type: application/json" \
  -d '{
    "hostname":"test-agent-1",
    "agent_type":"vector",
    "os_type":"Linux",
    "os_version":"Ubuntu 22.04",
    "agent_version":"0.44.0",
    "metadata":{"datacenter":"prod","environment":"production"}
  }'

# Response: Same agent_id returned, metadata updated
{
  "agent_id": "fea821ce-cd47-449b-90b2-63bb8c8adf0f",
  "status": "registered",
  "message": "Agent 'test-agent-1' registered successfully"
}

# Test 4: List all agents
curl -s https://192.168.5.32:8444/api/v1/agents \
  --cacert infrastructure/certs-new/ca/oasis-ca.pem \
  -H "Authorization: Bearer oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"

# Response: 200 OK
{
  "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
  "agent_count": 2,
  "agents": [
    {
      "id": "fea821ce-cd47-449b-90b2-63bb8c8adf0f",
      "hostname": "test-agent-1",
      "agent_type": "vector",
      "os_type": "Linux",
      "os_version": "Ubuntu 22.04",
      "agent_version": "0.44.0",
      "first_seen": "2026-01-10T21:38:49.302294+00:00",
      "last_seen": "2026-01-10T21:39:06.591084+00:00",
      "ip_address": "192.168.5.32",
      "metadata": "{\"datacenter\": \"prod\", \"environment\": \"production\"}",
      "is_active": true
    },
    {
      "id": "5e32aef1-dd56-4995-b2dd-da696ecb33a6",
      "hostname": "test-agent-2",
      "agent_type": "vector",
      "os_type": "Windows",
      "os_version": "Windows Server 2022",
      "agent_version": "0.43.0",
      "first_seen": "2026-01-10T21:39:03.845865+00:00",
      "last_seen": "2026-01-10T21:39:03.845865+00:00",
      "ip_address": "192.168.5.32",
      "metadata": "{}",
      "is_active": true
    }
  ]
}
```

### Verified Behaviors

✅ **Agent Creation**: New agents are assigned a UUID and stored in the database
✅ **Agent Update (Upsert)**: Re-registering an existing agent updates version, metadata, and last_seen
✅ **Unique Constraint**: tenant_id + hostname enforces uniqueness
✅ **IP Address Tracking**: Client IP is captured from the request
✅ **Metadata Storage**: JSON metadata is properly serialized and stored
✅ **Active Status**: `is_active` flag is set to true on registration
✅ **Timestamps**: `first_seen` persists, `last_seen` updates on each registration

---

## Next Steps: Integration Testing

### Prerequisites for Linux Testing

1. **Linux System Requirements**:
   - Ubuntu 20.04+ or similar systemd-based Linux
   - Sudo access
   - Network access to `192.168.5.32:8444`
   - curl installed

2. **Deploy O.A.S.I.S. CA Certificate** (one-time):
   ```bash
   # Copy CA cert from host
   scp infrastructure/certs-new/ca/oasis-ca.pem testuser@testhost:/tmp/
   ```

3. **Copy Deployment Script**:
   ```bash
   scp scripts/deploy-vector.sh testuser@testhost:/tmp/
   ```

### Linux Deployment Test Procedure

#### Step 1: Run Deployment Script

```bash
# On the test Linux machine
sudo bash /tmp/deploy-vector.sh
```

**Expected Output** (8 steps):
```
==============================================
O.A.S.I.S. Vector Agent Deployment - Linux
==============================================

Current OS: Linux
Architecture: x86_64
Hostname: testhost

[1/8] Installing Vector...
✓ Vector installed successfully: /usr/local/bin/vector

[2/8] Creating directories...
✓ Directories created

[3/8] Deploying secrets file...
✓ Secrets file created: /etc/vector/secrets.json

[4/8] Deploying CA certificate...
✓ CA certificate deployed: /etc/vector/certs/oasis-ca.pem

[5/8] Generating Vector configuration...
✓ Vector configuration deployed: /etc/vector/vector.yaml

[6/8] Validating Vector configuration...
✓ Configuration validated successfully

[7/8] Creating systemd service...
✓ Vector service created and started

[8/8] Registering agent with O.A.S.I.S....
✓ Agent registered successfully!

==============================================
Deployment complete!
==============================================

Vector is now running and forwarding logs to O.A.S.I.S.

Check status:  systemctl status vector
View logs:     journalctl -u vector -f
Agent info:    vector --version
```

#### Step 2: Verify Vector Service

```bash
# Check service status
systemctl status vector

# Expected: Active (running)

# View Vector logs
journalctl -u vector -f

# Expected: Logs showing successful connection to O.A.S.I.S.
# Look for lines like:
# - "Configuration validated successfully"
# - "Healthcheck passed"
# - "Successfully sent batch"
```

#### Step 3: Verify Agent Registration

```bash
# From O.A.S.I.S. host
curl -s https://192.168.5.32:8444/api/v1/agents \
  --cacert infrastructure/certs-new/ca/oasis-ca.pem \
  -H "Authorization: Bearer oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo" \
  | jq '.agents[] | select(.hostname == "testhost")'

# Expected: Agent entry with matching hostname
```

#### Step 4: Verify Logs in ClickHouse

```sql
-- In ClickHouse container
docker exec -it oasis-clickhouse clickhouse-client

-- Check for logs from the test agent
SELECT 
    count(*) as log_count,
    toStartOfMinute(ingested_at) as minute,
    any(source_type) as source
FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff
WHERE source_type = 'systemd_journal'
  AND ingested_at > now() - INTERVAL 10 MINUTE
GROUP BY minute
ORDER BY minute DESC
LIMIT 20;

-- View sample logs
SELECT 
    timestamp,
    severity,
    message,
    metadata
FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff
WHERE source_type = 'systemd_journal'
  AND ingested_at > now() - INTERVAL 5 MINUTE
ORDER BY timestamp DESC
LIMIT 50;
```

**Expected Results**:
- Log count increasing over time
- Logs with source_type = 'systemd_journal'
- Proper timestamps and metadata
- Messages from various system services

#### Step 5: Test Cleanup (Optional)

```bash
# On test machine
sudo bash /tmp/cleanup-vector.sh

# Expected:
# - Vector service stopped and removed
# - Vector binary removed
# - Config files removed
# - Data directories cleaned up
```

---

## Windows Deployment Test Procedure

### Prerequisites for Windows Testing

1. **Windows System Requirements**:
   - Windows 10/11 or Windows Server 2019+
   - PowerShell 5.1+ (included)
   - Administrator access
   - Network access to `192.168.5.32:8444`

2. **Copy Files to Windows Machine**:
   ```powershell
   # Copy deployment script and CA cert
   scp scripts/deploy-vector.ps1 Administrator@winhost:C:\Temp\
   scp infrastructure/certs-new/ca/oasis-ca.pem Administrator@winhost:C:\Temp\
   ```

3. **Set Execution Policy** (if needed):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Step 1: Run Deployment Script

```powershell
# Run PowerShell as Administrator
.\deploy-vector.ps1
```

**Expected Output** (similar to Linux version with 8 steps)

### Step 2: Verify Vector Service

```powershell
# Check service status
Get-Service Vector

# Expected: Status = Running

# View Vector logs
Get-Content C:\ProgramData\Vector\logs\vector.log -Wait

# Or use Event Viewer to see Vector logs
```

### Step 3: Verify Agent Registration

(Same as Linux - query the API from O.A.S.I.S. host)

### Step 4: Verify Windows Event Logs in ClickHouse

```sql
-- Check for Windows Event Logs
SELECT 
    count(*) as log_count,
    toStartOfMinute(ingested_at) as minute,
    any(source_type) as source
FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff
WHERE source_type = 'windows_event_log'
  AND ingested_at > now() - INTERVAL 10 MINUTE
GROUP BY minute
ORDER BY minute DESC
LIMIT 20;

-- View sample Windows events
SELECT 
    timestamp,
    severity,
    message,
    metadata
FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff
WHERE source_type = 'windows_event_log'
  AND ingested_at > now() - INTERVAL 5 MINUTE
ORDER BY timestamp DESC
LIMIT 50;
```

---

## Troubleshooting

### Agent Registration Fails

**Symptom**: Script reports "Failed to register agent"

**Possible Causes**:
1. Network connectivity to `192.168.5.32:8444`
2. Invalid API key
3. CA certificate mismatch
4. Firewall blocking HTTPS traffic

**Debug Steps**:
```bash
# Test network connectivity
curl -v https://192.168.5.32:8444/health

# Test with CA cert
curl --cacert /etc/vector/certs/oasis-ca.pem \
  https://192.168.5.32:8444/health

# Test API key
curl --cacert /etc/vector/certs/oasis-ca.pem \
  -H "Authorization: Bearer oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo" \
  https://192.168.5.32:8444/api/v1/agents
```

### Vector Service Won't Start

**Symptom**: `systemctl status vector` shows failed

**Debug Steps**:
```bash
# Check Vector config validation
vector validate --config-yaml /etc/vector/vector.yaml

# Check Vector logs
journalctl -u vector -n 50 --no-pager

# Test Vector in foreground
sudo /usr/local/bin/vector --config-yaml /etc/vector/vector.yaml
```

**Common Issues**:
- Secrets file not readable (check permissions: `ls -l /etc/vector/secrets.json`)
- CA certificate path wrong
- Invalid YAML syntax in config
- VRL syntax errors in transforms

### No Logs Appearing in ClickHouse

**Symptom**: Agent registered but no logs in ClickHouse

**Debug Steps**:
```bash
# Check Vector sink health
journalctl -u vector -f | grep -i "http\|sink\|error"

# Check O.A.S.I.S. Internal Gateway logs
docker logs -f oasis-internal-gateway | grep ingest

# Check Ingestion Service logs
docker logs -f oasis-ingestion-service

# Verify ClickHouse connection
docker exec -it oasis-clickhouse clickhouse-client --query "SELECT count(*) FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff"
```

**Common Issues**:
- Source filter too restrictive (Linux: priority > 6, Windows: level > 4)
- Insufficient log activity on test system
- Clock skew causing timestamp issues
- Buffer disk full (Vector disk buffer at `/var/lib/vector`)

---

## Success Criteria Checklist

### Agent Deployment
- [ ] Vector installs without errors
- [ ] Service starts successfully
- [ ] Configuration validates
- [ ] Agent registers with O.A.S.I.S. API

### Agent Registration
- [ ] Agent appears in `agents` table
- [ ] Agent shows in `GET /api/v1/agents` response
- [ ] `is_active` flag is true
- [ ] IP address is captured
- [ ] Metadata is stored correctly

### Log Ingestion
- [ ] Logs appear in ClickHouse within 5 minutes
- [ ] Timestamps are correct
- [ ] Metadata includes tenant_id, host, source_type
- [ ] Severity/priority filtering works
- [ ] Log volume is reasonable (not flooding)

### Re-registration
- [ ] Re-running deployment script updates agent
- [ ] `last_seen` timestamp updates
- [ ] Agent version updates if changed
- [ ] Same agent_id is retained

---

## Known Issues / Limitations

1. **macOS Not Supported**: Deferred due to Homebrew/sudo conflicts (see roadmap)

2. **Vector 0.50+ VRL Changes**: Error handling required for functions like `get_hostname()`
   - Fixed in configs with: `.host, _ = get_hostname()`

3. **Secrets File Security**: 
   - Linux: chmod 600, root-only
   - Windows: SYSTEM + Administrators only
   - Exposed in process list if using environment variables (we use file backend)

4. **Service Permissions**:
   - Linux: Vector runs as root (needed for journald)
   - Windows: Vector runs as SYSTEM (needed for Event Log)
   - Both increase security surface area

5. **Network Requirements**:
   - Agents need direct HTTPS access to gateway IP
   - Firewall rules may need updating
   - mTLS requires valid CA certificate

---

## Performance Expectations

### Linux (systemd journal)

- **Log Volume**: 100-1000 logs/minute typical
- **Filtering**: Priority ≤6 (INFO and above)
- **CPU Usage**: <5% idle, <15% under load
- **Memory**: 50-100 MB typical
- **Network**: 10-100 KB/s (with gzip compression)

### Windows (Event Log)

- **Log Volume**: 50-500 logs/minute typical
- **Filtering**: Level ≤4 (INFO and above)
- **CPU Usage**: <5% idle, <20% under load
- **Memory**: 80-150 MB typical
- **Network**: 15-150 KB/s (with gzip compression)

---

## Environment Details

### O.A.S.I.S. Configuration

- **Internal Gateway**: `https://192.168.5.32:8444`
- **API Key**: `oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo`
- **Tenant ID**: `ffffffff-ffff-ffff-ffff-ffffffffffff`
- **CA Cert**: `/home/aaron/code/oasis/infrastructure/certs-new/ca/oasis-ca.pem`

### Vector Configuration

- **Linux Config**: `/etc/vector/vector.yaml`
- **Linux Secrets**: `/etc/vector/secrets.json`
- **Linux Data**: `/var/lib/vector`
- **Windows Config**: `C:\ProgramData\Vector\config\vector.yaml`
- **Windows Secrets**: `C:\ProgramData\Vector\config\secrets.json`
- **Windows Data**: `C:\ProgramData\Vector\data`

---

## Next Phase: Production Hardening

After integration testing completes successfully, next steps:

1. **Multi-Tenant Support**: Update scripts to accept tenant-specific API keys
2. **Monitoring**: Add Prometheus metrics export from Vector
3. **Alerting**: Configure alerts for agent failures
4. **Log Rotation**: Implement Vector log file rotation
5. **Auto-Update**: Create mechanism to update Vector agents
6. **Dashboard**: Build agent status dashboard in UI
7. **Documentation**: Create user-facing deployment guides
8. **CI/CD**: Add automated testing for deployment scripts

---

## Contact / Support

For issues or questions:
- Check logs: `journalctl -u vector -f` (Linux) or Event Viewer (Windows)
- Review configuration: `/etc/vector/vector.yaml`
- Test connectivity: `curl https://192.168.5.32:8444/health`
- Check database: `docker exec oasis-postgresql psql -U admin -d oasis -c "SELECT * FROM agents;"`

**Last Updated**: 2026-01-10 (Phase 2 Complete)
