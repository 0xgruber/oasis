#!/bin/bash
# O.A.S.I.S. Vector Agent Deployment Script (Linux)
# 
# This script:
# 1. Installs Vector using official installer (Linux only)
# 2. Deploys configuration, secrets, and CA certificate
# 3. Creates systemd service
# 4. Registers agent with O.A.S.I.S.
# 
# Usage: sudo bash scripts/deploy-vector.sh

set -e  # Exit on error

# Configuration
OASIS_GATEWAY="https://192.168.5.32:8444"
OASIS_API_KEY="oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"

echo "========================================"
echo "O.A.S.I.S. Vector Agent Deployment"
echo "========================================"
echo ""

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
  echo "❌ ERROR: This script must be run as root (use sudo)"
  exit 1
fi

# Check required tools
echo "🔍 Checking prerequisites..."
MISSING_TOOLS=()

if ! command -v curl &> /dev/null; then
  MISSING_TOOLS+=("curl")
fi

if ! command -v systemctl &> /dev/null; then
  MISSING_TOOLS+=("systemctl")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "❌ ERROR: Missing required tools: ${MISSING_TOOLS[*]}"
  echo ""
  echo "Please install missing tools:"
  echo "   Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y curl systemd"
  echo "   RHEL/CentOS:   sudo yum install -y curl systemd"
  echo ""
  exit 1
fi

echo "   ✅ All prerequisites met"
echo ""

# Detect OS
OS_TYPE=$(uname -s)

if [ "$OS_TYPE" != "Linux" ]; then
  echo "❌ ERROR: This script only supports Linux"
  echo "   Detected OS: $OS_TYPE"
  echo ""
  echo "For Windows, use: scripts/deploy-vector.ps1"
  echo "For macOS, see roadmap (not yet supported)"
  exit 1
fi

ARCH=$(uname -m)
OS_VERSION=$(uname -r)

echo "🔍 Detected System:"
echo "   OS: Linux"
echo "   Architecture: $ARCH"
echo "   Kernel: $OS_VERSION"
echo ""

# Set paths
VECTOR_CONFIG_DIR="/etc/vector"
VECTOR_CONFIG="$VECTOR_CONFIG_DIR/vector.yaml"
VECTOR_SECRETS="$VECTOR_CONFIG_DIR/secrets.json"
VECTOR_CERTS_DIR="$VECTOR_CONFIG_DIR/certs"
VECTOR_CA_CERT="$VECTOR_CERTS_DIR/oasis-ca.pem"
VECTOR_DATA_DIR="/var/lib/vector"
SERVICE_FILE="/etc/systemd/system/vector.service"

echo "📁 Installation Paths:"
echo "   Config: $VECTOR_CONFIG"
echo "   Secrets: $VECTOR_SECRETS"
echo "   CA Cert: $VECTOR_CA_CERT"
echo "   Data: $VECTOR_DATA_DIR"
echo "   Service: $SERVICE_FILE"
echo ""

# Step 1: Install Vector
echo "📦 Step 1/8: Installing Vector..."

# Check if already installed
if command -v vector &> /dev/null; then
  EXISTING_VERSION=$(vector --version 2>/dev/null | awk '{print $2}')
  echo "   ⚠️  Vector already installed: $EXISTING_VERSION"
  read -p "   Reinstall? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    SKIP_INSTALL=true
  fi
fi

if [ "$SKIP_INSTALL" != "true" ]; then
  echo "   📥 Installing Vector via official installer..."
  curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y
fi

# Detect actual Vector installation location
VECTOR_BIN=$(command -v vector 2>/dev/null)

if [ -z "$VECTOR_BIN" ]; then
  echo "   ❌ ERROR: Vector binary not found after installation"
  echo "   Please check installation logs above for errors."
  exit 1
fi

VECTOR_VERSION=$($VECTOR_BIN --version | awk '{print $2}')
echo "   ✅ Vector installed: $VECTOR_VERSION"
echo "   ✅ Vector binary: $VECTOR_BIN"
echo ""

# Step 2: Create directories
echo "📁 Step 2/8: Creating directories..."
mkdir -p "$VECTOR_CONFIG_DIR"
mkdir -p "$VECTOR_CERTS_DIR"
mkdir -p "$VECTOR_DATA_DIR"
echo "   ✅ Directories created"
echo ""

# Step 3: Deploy secrets file
echo "🔐 Step 3/8: Deploying secrets file..."
cat > "$VECTOR_SECRETS" <<'EOF'
{
  "oasis_api_key": "oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"
}
EOF
chmod 600 "$VECTOR_SECRETS"
echo "   ✅ Secrets file deployed: $VECTOR_SECRETS (permissions: 600)"
echo ""

# Step 4: Deploy CA certificate
echo "🔒 Step 4/8: Deploying O.A.S.I.S. CA certificate..."
cat > "$VECTOR_CA_CERT" <<'EOF'
-----BEGIN CERTIFICATE-----
MIIFuTCCA6GgAwIBAgIUKwFNPfUo/loTyNkxG+VWj4LdjXEwDQYJKoZIhvcNAQEL
BQAwbDELMAkGA1UEBhMCVVMxEzARBgNVBAgMCkNhbGlmb3JuaWExFjAUBgNVBAcM
DVNhbiBGcmFuY2lzY28xEzARBgNVBAoMCk8uQS5TLkkuUy4xGzAZBgNVBAMMEk8u
QS5TLkkuUy4gUm9vdCBDQTAeFw0yNjAxMTAxNTAxMzJaFw0zNjAxMDgxNTAxMzJa
MGwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQHDA1T
YW4gRnJhbmNpc2NvMRMwEQYDVQQKDApPLkEuUy5JLlMuMRswGQYDVQQDDBJPLkEu
Uy5JLlMuIFJvb3QgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDo
YPSd32EPvVYJ0w8azP1vPj9v3f931aPgFdjNYYM6BnsG5t6NJ15olHcRoxlhpEAv
0aznPHpdVv8zXHr72ghHbN+AoMAPv9Lh3QilChQs1PN3JlAhU1tV69RZ9fUzRijC
P1GAKPNYCRPjbPaVo0KXNXmafmPe5h0MTbjPBwlMJVI8zeOKPwrUhaozu5MEhNsl
OhtEHBBaoSLR7WYtVkgw3cB/EomUqbMmjL9/Jihys8qXyTZ4GEqNbSEQMUvFU8Kx
IV6VN4RNsJn7Cf4/P+Yzienzdj6woruIMitLlpm+/7xQrUZukAsCHtdw4zFz7xTA
5Pk3hCSd4a5IwUVOMxQ1GJulMMFsaEfj3Z3aemI7qPHE2mjCFMgFNwXki4wvc1BU
RKfhUbLjj+3tmzL62Ux7MJyBM8aLBlfIhY0ZduegI0jhANxWDSyIV7k5lVlAtzwZ
5nyHSqTO6BqvVIxZX0i0omQ0ENwKfiWDkeyLki6Ehc2KTDRZvno6uXOKODFNCNY9
M06fqPoc2eDKpJDnXefYFYU53mmBjIb6gWyMzO1DtOprt6/9AN39kKYLQqH40/sm
wg8FT1kvU+PuB4qNCErpH1cvgq6wKLGoPBGF5FMqYo+ySHJCY8sUQY18DP/7bwpc
NasqiTDiSUdH58Iy5ORgiOCEii170kKm4nB/fksUIQIDAQABo1MwUTAdBgNVHQ4E
FgQUaiWuWh6S5NDtKgoiYOp8+a11bkowHwYDVR0jBBgwFoAUaiWuWh6S5NDtKgoi
YOp8+a11bkowDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAhwE+
8OvZ3zS1am1VPA+MQhTN/NgQfLpQU3KXBpEof1MwJs8uxOnLLmcJE8qYuhK6J4TM
0V8HI86aZjSf5GPz3fRqN2KsUHgTOhiSz2Z85DxbeIh+qi6+n2+jGzhlbEBs+ZfV
jL1cMuaLoqHPO2gEW7Gsrgoa1xibSU9ZbkQ5XAVEX9SpWZTmLFpAnQ2jsPYnQsfq
Dkbe1AfNxGTdOhhsf91Ce9VzpT9nGTWDekj+dCK/n0a4t0iXE5hz7VMhgV9mwubu
JkJVe1sLC/xv9PT1lkAqbafHJDvBulPAE4RdsPcO65JITvP8AdnQG46ubR2d3hPm
nhc+6n2md7Db1P1dap+yl9qhrp4ox2f9PkVMbUm56NlZtt/tTbmeT1bmkIovG2B+
MR2HTVrrVJp3FDtJw5AlL4Ks6fMXA1eLp2zKsqUCr3nqNngCSpQorTDhTjeg5hNh
4d3my7FgksmV2nc2HuLuusuSa2a6wHbYLPKP9TD8t/S8uxc9j6XySGM5Bop14bWW
4/vwNFnGPD/nvdvQNt6ZeHTmvMnfRLmV6tjeeeUVI/MbPTpGF6FmzOua6FW8iSiY
2XET9qTHjyekF+rfjeM2SNjAf/BUjyyiXciMWXWV8HpVkBcAZFBsh9FcbyN/qu22
rwxt2UiUp2EGtMav9nV450T6zXI74DV8KJQQRsE=
-----END CERTIFICATE-----
EOF
chmod 644 "$VECTOR_CA_CERT"
echo "   ✅ CA certificate deployed: $VECTOR_CA_CERT (permissions: 644)"
echo ""

# Step 5: Deploy Vector configuration
echo "⚙️  Step 5/8: Deploying Vector configuration..."

cat > "$VECTOR_CONFIG" <<EOF
# Vector Configuration: Linux Systemd Journal - PRODUCTION
# Managed by O.A.S.I.S. deployment script
# Generated: $(date)

# Secrets backend
secret:
  oasis_secrets:
    type: file
    path: $VECTOR_SECRETS

# Data source: Systemd Journal
sources:
  journald:
    type: journald
    current_boot_only: true

# Transform: Enrich and filter
transforms:
  enrich_journal:
    type: remap
    inputs:
      - journald
    source: |
      .host, _ = get_hostname()
      .oasis_tenant = "internal"
      .timestamp = to_unix_timestamp(now())
      .source_type = "systemd_journal"
      .severity = .PRIORITY
      .unit = ._SYSTEMD_UNIT
      .message = .MESSAGE

  filter_priority:
    type: filter
    inputs:
      - enrich_journal
    condition: 'to_int(.PRIORITY) <= 6'

# Sink: O.A.S.I.S. Internal Gateway
sinks:
  oasis_gateway:
    type: http
    inputs:
      - filter_priority
    uri: $OASIS_GATEWAY/api/v1/ingest
    method: post
    compression: gzip
    encoding:
      codec: json
    batch:
      max_bytes: 1048576
      timeout_secs: 5
    request:
      headers:
        Authorization: "Bearer SECRET[oasis_secrets.oasis_api_key]"
        Content-Type: "application/json"
    tls:
      ca_file: $VECTOR_CA_CERT
      verify_certificate: true
      verify_hostname: true
    buffer:
      type: disk
      max_size: 268435488
      when_full: block
EOF

chmod 644 "$VECTOR_CONFIG"
echo "   ✅ Configuration deployed: $VECTOR_CONFIG"
echo ""

# Step 6: Validate configuration
echo "✔️  Step 6/8: Validating configuration..."
if $VECTOR_BIN validate --config "$VECTOR_CONFIG"; then
  echo "   ✅ Configuration is valid"
else
  echo "   ❌ ERROR: Configuration validation failed"
  exit 1
fi
echo ""

# Step 7: Create and start systemd service
echo "🚀 Step 7/8: Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Vector Log Collection Agent
Documentation=https://vector.dev/docs/
After=network.target

[Service]
Type=simple
User=root
ExecStart=$VECTOR_BIN --config $VECTOR_CONFIG
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable vector.service
systemctl restart vector.service

echo "   ✅ systemd unit created and started: $SERVICE_FILE"
echo ""

# Wait for service to start
echo "⏳ Waiting 5 seconds for service to start..."
sleep 5
echo ""

# Step 8: Verify service is running
echo "🔍 Step 8/8: Verifying service status..."
if systemctl is-active --quiet vector.service; then
  echo "   ✅ Vector service is running"
  systemctl status vector.service --no-pager -l | head -10
else
  echo "   ❌ ERROR: Vector service is not running"
  echo "   Check logs: journalctl -u vector.service -n 50"
  exit 1
fi
echo ""

# Register agent with O.A.S.I.S.
echo "📝 Registering agent with O.A.S.I.S..."
HOSTNAME=$(hostname)
REGISTRATION_RESPONSE=$(curl -s -X POST "$OASIS_GATEWAY/api/v1/agents/register" \
  -H "Authorization: Bearer $OASIS_API_KEY" \
  -H "Content-Type: application/json" \
  --cacert "$VECTOR_CA_CERT" \
  -d "{\"hostname\":\"$HOSTNAME\",\"agent_type\":\"vector\",\"os_type\":\"Linux\",\"os_version\":\"$OS_VERSION\",\"agent_version\":\"$VECTOR_VERSION\"}" \
  2>&1)

if echo "$REGISTRATION_RESPONSE" | grep -q "agent_id"; then
  echo "   ✅ Agent registered successfully"
  echo "   Response: $REGISTRATION_RESPONSE"
else
  echo "   ⚠️  WARNING: Agent registration may have failed"
  echo "   Response: $REGISTRATION_RESPONSE"
  echo "   (Logs will still be sent, but agent may not appear in dashboard)"
fi
echo ""

# Summary
echo "========================================"
echo "✅ Deployment Complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  Vector Version: $VECTOR_VERSION"
echo "  Config: $VECTOR_CONFIG"
echo "  Service: $SERVICE_FILE"
echo "  O.A.S.I.S. Gateway: $OASIS_GATEWAY"
echo ""
echo "Next Steps:"
echo "  1. Monitor logs:"
echo "     journalctl -u vector.service -f"
echo "  2. Check service status:"
echo "     systemctl status vector.service"
echo "  3. Verify logs in O.A.S.I.S. dashboard"
echo ""
echo "To uninstall, run: sudo bash scripts/cleanup-vector.sh"
echo ""
