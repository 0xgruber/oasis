# Vector Agent Deployment Guide - Production TLS Setup

## Overview
This guide covers deploying Vector log collection agents to Linux and macOS machines with full TLS encryption to the O.A.S.I.S. platform.

## Prerequisites
- O.A.S.I.S. Internal Gateway running on: `https://192.168.5.32:8444`
- API Key: `oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo`
- CA Certificate: `/home/aaron/code/oasis/infrastructure/certs-new/ca/oasis-ca.pem`

---

## Part 1: Linux Deployment (Ubuntu/Debian)

### Step 1: Install Vector

```bash
# Add Vector repository
curl -1sLf 'https://repositories.timber.io/public/vector/cfg/setup/bash.deb.sh' | sudo -E bash

# Install Vector
sudo apt-get update
sudo apt-get install vector
```

### Step 2: Deploy CA Certificate

On the **O.A.S.I.S. host** (aurora):
```bash
# Copy CA certificate to a temporary location
scp /home/aaron/code/oasis/infrastructure/certs-new/ca/oasis-ca.pem user@target-machine:/tmp/
```

On the **target Linux machine**:
```bash
# Create certificate directory
sudo mkdir -p /etc/vector/certs

# Move CA certificate
sudo mv /tmp/oasis-ca.pem /etc/vector/certs/

# Set permissions
sudo chmod 644 /etc/vector/certs/oasis-ca.pem
sudo chown vector:vector /etc/vector/certs/oasis-ca.pem
```

### Step 3: Deploy Vector Configuration

On the **O.A.S.I.S. host**:
```bash
scp /home/aaron/code/oasis/VECTOR_EXAMPLES/linux-systemd-production.toml user@target-machine:/tmp/vector.toml
```

On the **target Linux machine**:
```bash
# Backup existing config (if any)
sudo mv /etc/vector/vector.toml /etc/vector/vector.toml.bak 2>/dev/null || true

# Install new config
sudo mv /tmp/vector.toml /etc/vector/vector.toml

# Set permissions
sudo chown vector:vector /etc/vector/vector.toml
sudo chmod 644 /etc/vector/vector.toml
```

### Step 4: Set API Key Environment Variable

```bash
# Edit Vector systemd service
sudo systemctl edit vector

# Add these lines in the editor:
[Service]
Environment="OASIS_API_KEY=oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"

# Save and exit (Ctrl+X, then Y, then Enter)
```

### Step 5: Start and Verify Vector

```bash
# Reload systemd
sudo systemctl daemon-reload

# Restart Vector
sudo systemctl restart vector

# Check status
sudo systemctl status vector

# View logs
sudo journalctl -u vector -f

# Expected output should include:
# - "Vector has started"
# - No TLS or certificate errors
# - Successful HTTP POST requests to https://192.168.5.32:8444/api/v1/ingest
```

### Step 6: Verify Logs in O.A.S.I.S.

On the **O.A.S.I.S. host**:
```bash
# Query ClickHouse for logs from the new source
docker compose exec clickhouse clickhouse-client --query "
SELECT 
  message, 
  raw_log,
  ingested_at 
FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff 
WHERE ingested_at > now() - INTERVAL 5 MINUTE
ORDER BY ingested_at DESC 
LIMIT 10 
FORMAT Pretty
"
```

---

## Part 2: macOS Deployment

### Step 1: Install Vector

```bash
# Install via Homebrew
brew tap vectordotdev/brew
brew install vector
```

### Step 2: Deploy CA Certificate

On the **O.A.S.I.S. host**:
```bash
scp /home/aaron/code/oasis/infrastructure/certs-new/ca/oasis-ca.pem user@mac-machine:/tmp/
```

On the **target macOS machine**:
```bash
# Create certificate directory
sudo mkdir -p /usr/local/etc/vector/certs

# Move CA certificate
sudo mv /tmp/oasis-ca.pem /usr/local/etc/vector/certs/

# Set permissions
sudo chmod 644 /usr/local/etc/vector/certs/oasis-ca.pem
```

### Step 3: Deploy Vector Configuration

On the **O.A.S.I.S. host**:
```bash
scp /home/aaron/code/oasis/VECTOR_EXAMPLES/macos-unified-log-production.toml user@mac-machine:/tmp/vector.toml
```

On the **target macOS machine**:
```bash
# Backup existing config (if any)
mv /usr/local/etc/vector/vector.toml /usr/local/etc/vector/vector.toml.bak 2>/dev/null || true

# Install new config
sudo mv /tmp/vector.toml /usr/local/etc/vector/vector.toml

# Set permissions
sudo chmod 644 /usr/local/etc/vector/vector.toml
```

### Step 4: Set API Key Environment Variable

```bash
# Create launchd plist override
sudo mkdir -p /Library/LaunchDaemons

# Create environment plist
sudo tee /Library/LaunchDaemons/dev.vector.environment.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.vector.environment</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/launchctl</string>
        <string>setenv</string>
        <string>OASIS_API_KEY</string>
        <string>oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the environment
sudo launchctl load /Library/LaunchDaemons/dev.vector.environment.plist
```

Alternative: Export in shell profile (user-level only):
```bash
echo 'export OASIS_API_KEY="oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"' >> ~/.zshrc
source ~/.zshrc
```

### Step 5: Start and Verify Vector

```bash
# Start Vector service
brew services start vector

# Check status
brew services list | grep vector

# View logs
tail -f /usr/local/var/log/vector.log

# Or use system log
log show --predicate 'process == "vector"' --last 5m
```

### Step 6: Verify Logs in O.A.S.I.S.

Same as Linux Step 6 above.

---

## Part 3: Troubleshooting

### Common Issues

#### 1. TLS Certificate Verification Failed
**Error:** `certificate verify failed`

**Solution:**
```bash
# Linux
ls -la /etc/vector/certs/oasis-ca.pem
sudo chmod 644 /etc/vector/certs/oasis-ca.pem

# macOS
ls -la /usr/local/etc/vector/certs/oasis-ca.pem
sudo chmod 644 /usr/local/etc/vector/certs/oasis-ca.pem
```

#### 2. API Key Authentication Failed
**Error:** `401 Unauthorized` or `Invalid API key`

**Solution:**
- Verify the API key is set correctly:
  ```bash
  # Linux
  sudo systemctl show vector --property=Environment
  
  # macOS
  echo $OASIS_API_KEY
  ```
- Check the Authorization header format in logs (should be `Bearer <key>`)

#### 3. Connection Refused
**Error:** `Connection refused` or `Could not connect`

**Solution:**
- Verify gateway is accessible:
  ```bash
  curl -k https://192.168.5.32:8444/health
  ```
- Check network connectivity and firewall rules

#### 4. No Logs Appearing in O.A.S.I.S.
**Solution:**
- Check Vector is running and collecting logs
- Verify Vector buffer directory has space:
  ```bash
  # Linux
  df -h /var/lib/vector/
  
  # macOS
  df -h /usr/local/var/lib/vector/
  ```
- Check Vector internal metrics:
  ```bash
  curl http://localhost:9598/metrics | grep oasis_gateway
  ```

---

## Part 4: Validation

### End-to-End Test

On **any deployed machine**:
```bash
# Linux: Generate a test log
logger -t oasis-test "This is a test log from $(hostname)"

# macOS: Generate a test log
log show --predicate 'process == "syslogd"' --last 1m
```

On **O.A.S.I.S. host**:
```bash
# Wait 60 seconds, then check
docker compose exec clickhouse clickhouse-client --query "
SELECT 
  count(*) as log_count,
  uniqExact(raw_log['host']) as unique_hosts
FROM oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff 
WHERE ingested_at > now() - INTERVAL 5 MINUTE
"
```

Expected output:
```
log_count | unique_hosts
----------+-------------
    150   |      2
```

---

## Part 5: Security Notes

### API Key Security
- **Never** commit the API key to git
- Store in environment variables or secure secret management
- Rotate periodically (regenerate with `/home/aaron/code/oasis/scripts/generate_api_key.py`)

### CA Certificate
- The `oasis-ca.pem` file is the root CA certificate
- It's safe to distribute (public certificate, not private key)
- Used only to verify the gateway's identity

### Network Security
- All traffic encrypted with TLS 1.3
- Gateway validates API keys before accepting logs
- mTLS used internally between gateway and ingestion service

---

## Quick Reference

### File Locations

| Component | Linux | macOS |
|-----------|-------|-------|
| Config | `/etc/vector/vector.toml` | `/usr/local/etc/vector/vector.toml` |
| CA Cert | `/etc/vector/certs/oasis-ca.pem` | `/usr/local/etc/vector/certs/oasis-ca.pem` |
| Logs | `journalctl -u vector` | `/usr/local/var/log/vector.log` |
| Data | `/var/lib/vector/` | `/usr/local/var/lib/vector/` |

### Service Commands

| Action | Linux | macOS |
|--------|-------|-------|
| Start | `sudo systemctl start vector` | `brew services start vector` |
| Stop | `sudo systemctl stop vector` | `brew services stop vector` |
| Restart | `sudo systemctl restart vector` | `brew services restart vector` |
| Status | `sudo systemctl status vector` | `brew services list \| grep vector` |
| Logs | `sudo journalctl -u vector -f` | `tail -f /usr/local/var/log/vector.log` |

### API Endpoints

| Endpoint | URL |
|----------|-----|
| Gateway Health | `https://192.168.5.32:8444/health` |
| Ingestion | `https://192.168.5.32:8444/api/v1/ingest` |
| Dashboard | `http://192.168.5.32:3000` |

---

## Next Steps

1. Deploy to first Linux machine and verify
2. Deploy to macOS machine and verify  
3. Monitor dashboard for incoming logs
4. Set up alerts for Vector agent failures (future work)
5. Document any site-specific configuration changes
