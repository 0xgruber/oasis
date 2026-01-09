# Vector Agent Configuration Examples

This directory contains example Vector configurations for collecting logs from various sources and sending them to O.A.S.I.S.

## What is Vector?

[Vector](https://vector.dev) is a high-performance, cross-platform log collector and router developed by Datadog. O.A.S.I.S. uses Vector as the primary log collection agent for endpoints (workstations, servers) due to its:

- **Cross-platform support**: Windows, Linux, macOS
- **Low resource footprint**: ~50MB memory
- **High performance**: Written in Rust
- **Reliability**: Built-in buffering and retries
- **Flexibility**: 100+ sources, rich transforms, multiple outputs

## Configuration Files

| File | Description | Platform |
|------|-------------|----------|
| `windows-event-logs.toml` | Collect Windows Event Log (Security, System, Application) | Windows |
| `linux-syslog.toml` | Collect Linux syslog from `/var/log/` | Linux |
| `linux-systemd.toml` | Collect systemd journal logs | Linux |
| `macos-unified-log.toml` | Collect macOS Unified Log | macOS |
| `docker-logs.toml` | Collect Docker container logs | Linux/macOS/Windows |

## Prerequisites

1. **Install Vector**: See [Vector Installation Guide](https://vector.dev/docs/setup/installation/)
2. **O.A.S.I.S. API Key**: Generate via SOC Portal → Tenants → Regenerate API Key
3. **O.A.S.I.S. CA Certificate**: Download via SOC Portal → Certificates → Download CA

## Quick Start

### 1. Install Vector

**Linux (Debian/Ubuntu):**
```bash
curl -1sLf 'https://repositories.timber.io/public/vector/cfg/setup/bash.deb.sh' | sudo bash
sudo apt install vector
```

**Linux (RHEL/CentOS):**
```bash
curl -1sLf 'https://repositories.timber.io/public/vector/cfg/setup/bash.rpm.sh' | sudo bash
sudo yum install vector
```

**macOS (Homebrew):**
```bash
brew tap vectordotdev/brew
brew install vector
```

**Windows (MSI Installer):**
Download from [Vector Releases](https://github.com/vectordotdev/vector/releases)

### 2. Download O.A.S.I.S. CA Certificate

Via SOC Portal:
1. Navigate to **Certificates** → **ca**
2. Click **Download**
3. Save as `oasis-ca.pem`

Via command line:
```bash
# Linux/macOS
sudo mkdir -p /etc/vector/certs
sudo curl -o /etc/vector/certs/oasis-ca.pem https://soc-portal.oasis-siem.local/certificates/ca/download

# Windows
New-Item -ItemType Directory -Path "C:\Program Files\Vector\certs" -Force
Invoke-WebRequest -Uri "https://soc-portal.oasis-siem.local/certificates/ca/download" -OutFile "C:\Program Files\Vector\certs\oasis-ca.pem"
```

### 3. Set API Key Environment Variable

**Linux/macOS:**
```bash
export OASIS_API_KEY="oasis_pk_YOUR_API_KEY_HERE"

# Persist in shell profile
echo 'export OASIS_API_KEY="oasis_pk_YOUR_API_KEY_HERE"' >> ~/.bashrc
```

**Windows (PowerShell):**
```powershell
$env:OASIS_API_KEY = "oasis_pk_YOUR_API_KEY_HERE"

# Persist system-wide
[System.Environment]::SetEnvironmentVariable('OASIS_API_KEY', 'oasis_pk_YOUR_API_KEY_HERE', [System.EnvironmentVariableTarget]::Machine)
```

### 4. Copy Configuration File

**Linux/macOS:**
```bash
# Choose appropriate config file
sudo cp linux-syslog.toml /etc/vector/vector.toml

# Or for systemd
sudo cp linux-systemd.toml /etc/vector/vector.toml
```

**Windows:**
```powershell
Copy-Item windows-event-logs.toml "C:\Program Files\Vector\config\vector.toml"
```

### 5. Edit Configuration

Update the following fields in the config file:

```toml
# Line 12: Replace with your tenant name
.oasis_tenant = "your-tenant-name"

# Line 19: Replace with your gateway URL
uri = "https://YOUR-GATEWAY-URL/ingest"

# Line 27: Verify CA certificate path
ca_file = "/etc/vector/certs/oasis-ca.pem"
```

### 6. Start Vector

**Linux (systemd):**
```bash
sudo systemctl enable vector
sudo systemctl start vector
sudo systemctl status vector
```

**macOS (Homebrew):**
```bash
brew services start vector
brew services list
```

**Windows (Service):**
```powershell
# Install as Windows Service
& "C:\Program Files\Vector\bin\vector.exe" --service install
Start-Service vector
Get-Service vector
```

### 7. Verify Logs in O.A.S.I.S.

1. Open SOC Portal
2. Navigate to **Logs**
3. Filter by tenant and time range
4. You should see logs appearing within 5-10 seconds

## Configuration Customization

### Change Log Sources

**Windows Event Log - Add more channels:**
```toml
[sources.windows_events]
channels = ["Security", "System", "Application", "Microsoft-Windows-Sysmon/Operational"]
```

**Linux Syslog - Add more files:**
```toml
[sources.linux_syslog]
include = ["/var/log/syslog", "/var/log/auth.log", "/var/log/nginx/access.log"]
```

**Systemd - Filter by units:**
```toml
[sources.journald]
units = ["ssh.service", "nginx.service", "docker.service", "kubelet.service"]
```

### Adjust Batch Size and Timeout

Larger batches = higher throughput, higher latency:
```toml
[sinks.oasis_gateway]
batch.max_bytes = 2097152  # 2MB (default: 1MB)
batch.timeout_secs = 10     # 10s (default: 5s)
```

Smaller batches = lower latency, more HTTP requests:
```toml
[sinks.oasis_gateway]
batch.max_bytes = 524288    # 512KB
batch.timeout_secs = 2      # 2s
```

### Add Filtering

Filter by severity:
```toml
[transforms.filter_severity]
type = "filter"
inputs = ["parse_syslog"]
condition = '.severity == "error" || .severity == "critical"'
```

Filter by pattern:
```toml
[transforms.filter_pattern]
type = "filter"
inputs = ["windows_events"]
condition = 'contains(.message, "failed login") || contains(.message, "authentication error")'
```

### Add Sampling

Sample 10% of logs (useful for high-volume sources):
```toml
[transforms.sample_logs]
type = "sample"
inputs = ["linux_syslog"]
rate = 10  # Keep 10%, drop 90%
```

## Troubleshooting

### Vector not starting

**Check logs:**
```bash
# Linux
sudo journalctl -u vector -f

# macOS
tail -f /usr/local/var/log/vector.log

# Windows
Get-EventLog -LogName Application -Source Vector
```

**Common issues:**
- Invalid TOML syntax: Run `vector validate /etc/vector/vector.toml`
- Missing API key: Ensure `OASIS_API_KEY` environment variable is set
- CA certificate not found: Verify path in `ca_file` field

### No logs appearing in O.A.S.I.S.

**Check Vector is sending:**
```bash
# Linux/macOS
curl -H "X-API-Key: $OASIS_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"message": "test", "timestamp": 1234567890}' \
     https://YOUR-GATEWAY-URL/ingest

# Windows
Invoke-WebRequest -Uri "https://YOUR-GATEWAY-URL/ingest" -Method Post `
  -Headers @{"X-API-Key"=$env:OASIS_API_KEY; "Content-Type"="application/json"} `
  -Body '{"message": "test", "timestamp": 1234567890}'
```

**Check O.A.S.I.S. gateway logs:**
```bash
# If deployed with Docker Compose
docker logs external-gateway -f
```

**Common issues:**
- Invalid API key: Verify key is correct and tenant is active
- Rate limit exceeded: Check tenant rate limit in SOC Portal
- TLS certificate error: Ensure `oasis-ca.pem` is downloaded correctly

### High memory usage

**Reduce buffer size:**
```toml
[sinks.oasis_gateway.buffer]
max_size = 134217728  # 128MB (default: 256MB)
```

**Increase batch frequency:**
```toml
[sinks.oasis_gateway]
batch.timeout_secs = 1  # Send more frequently
```

## Performance Tuning

### Recommended Settings

**Low-volume endpoints** (<100 EPS):
```toml
batch.max_bytes = 524288      # 512KB
batch.timeout_secs = 10       # 10s
buffer.max_size = 134217728   # 128MB
```

**Medium-volume endpoints** (100-1000 EPS):
```toml
batch.max_bytes = 1048576     # 1MB (default)
batch.timeout_secs = 5        # 5s (default)
buffer.max_size = 268435456   # 256MB (default)
```

**High-volume endpoints** (>1000 EPS):
```toml
batch.max_bytes = 2097152     # 2MB
batch.timeout_secs = 2        # 2s
buffer.max_size = 536870912   # 512MB
```

## Advanced: Multiple Outputs

Send logs to O.A.S.I.S. and backup location simultaneously:

```toml
# Primary: O.A.S.I.S.
[sinks.oasis_gateway]
type = "http"
inputs = ["enrich"]
uri = "https://external-gateway.oasis-siem.com/ingest"
# ... (same as above)

# Backup: Local file
[sinks.local_backup]
type = "file"
inputs = ["enrich"]
path = "/var/log/oasis-backup/%Y-%m-%d.log"
encoding.codec = "json"
```

## Resources

- [Vector Documentation](https://vector.dev/docs/)
- [Vector Configuration Reference](https://vector.dev/docs/reference/configuration/)
- [Vector Remap Language (VRL)](https://vector.dev/docs/reference/vrl/)
- [O.A.S.I.S. Documentation](https://github.com/0xgruber/oasis)

## Support

- 🐛 Report issues: [GitHub Issues](https://github.com/0xgruber/oasis/issues)
- 💬 Ask questions: [GitHub Discussions](https://github.com/0xgruber/oasis/discussions)
- 📧 Email: support@oasis-siem.org
