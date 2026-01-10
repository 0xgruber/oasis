#!/bin/bash
# O.A.S.I.S. Vector Agent Deployment Script
# 
# This script:
# 1. Detects OS (macOS vs Linux) and architecture
# 2. Installs Vector (Homebrew for macOS, official installer for Linux)
# 3. Deploys configuration, secrets, and CA certificate
# 4. Creates system-level service (LaunchDaemon or systemd)
# 5. Registers agent with O.A.S.I.S.
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

# Detect OS and architecture
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

echo "🔍 Detected System:"
echo "   OS: $OS_TYPE"
echo "   Architecture: $ARCH"
echo ""

# Get OS version
if [ "$OS_TYPE" = "Darwin" ]; then
  OS_VERSION=$(sw_vers -productVersion)
elif [ "$OS_TYPE" = "Linux" ]; then
  OS_VERSION=$(uname -r)
else
  echo "❌ ERROR: Unsupported OS: $OS_TYPE"
  exit 1
fi

# Step 1: Install Vector
echo "📦 Step 1/8: Installing Vector..."

if [ "$OS_TYPE" = "Darwin" ]; then
  # macOS: Require Homebrew (official installer doesn't support Intel macOS)
  echo "   Checking for Homebrew..."
  
  if ! command -v brew &> /dev/null; then
    echo "   ⚠️  Homebrew not found"
    echo ""
    echo "   Vector's official installer does not support Intel macOS."
    echo "   Homebrew is required for macOS installation."
    echo "   More info: https://brew.sh"
    echo ""
    read -p "   Install Homebrew now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "   📥 Installing Homebrew..."
      # Run Homebrew installer (will prompt for password)
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      
      # Add Homebrew to PATH for this session
      if [ "$ARCH" = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      
      if ! command -v brew &> /dev/null; then
        echo "   ❌ ERROR: Homebrew installation failed"
        exit 1
      fi
      echo "   ✅ Homebrew installed"
    else
      echo "   ❌ ERROR: Cannot proceed without Homebrew"
      exit 1
    fi
  else
    echo "   ✅ Homebrew found: $(brew --version | head -n1)"
  fi
  
  # Check if Vector already installed
  if brew list vector &>/dev/null; then
    EXISTING_VERSION=$(brew info --json vector | grep -o '"version":"[^"]*' | cut -d'"' -f4)
    echo "   ⚠️  Vector already installed via Homebrew: $EXISTING_VERSION"
    read -p "   Reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "   🔄 Reinstalling Vector..."
      brew reinstall vector
    fi
  else
    echo "   📥 Installing Vector via Homebrew..."
    brew tap vectordotdev/brew 2>/dev/null || true
    brew install vector
  fi
  
elif [ "$OS_TYPE" = "Linux" ]; then
  # Linux: Official installer works fine
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

# Derive configuration paths from binary location
if [ "$OS_TYPE" = "Darwin" ]; then
  # macOS Homebrew paths
  if [[ "$VECTOR_BIN" == "/opt/homebrew"* ]]; then
    # Apple Silicon
    VECTOR_CONFIG_DIR="/opt/homebrew/etc/vector"
    VECTOR_DATA_DIR="/opt/homebrew/var/lib/vector"
  else
    # Intel
    VECTOR_CONFIG_DIR="/usr/local/etc/vector"
    VECTOR_DATA_DIR="/usr/local/var/lib/vector"
  fi
  SERVICE_FILE="/Library/LaunchDaemons/io.vector.agent.plist"
elif [ "$OS_TYPE" = "Linux" ]; then
  VECTOR_CONFIG_DIR="/etc/vector"
  VECTOR_DATA_DIR="/var/lib/vector"
  SERVICE_FILE="/etc/systemd/system/vector.service"
fi

VECTOR_CONFIG="$VECTOR_CONFIG_DIR/vector.yaml"
VECTOR_SECRETS="$VECTOR_CONFIG_DIR/secrets.json"
VECTOR_CERTS_DIR="$VECTOR_CONFIG_DIR/certs"
VECTOR_CA_CERT="$VECTOR_CERTS_DIR/oasis-ca.pem"

echo "   ✅ Config directory: $VECTOR_CONFIG_DIR"
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

if [ "$OS_TYPE" = "Darwin" ]; then
  # macOS configuration (YAML)
  cat > "$VECTOR_CONFIG" <<EOF
# Vector Configuration: macOS Unified Log - PRODUCTION
# Managed by O.A.S.I.S. deployment script
# Generated: $(date)

# Secrets backend
secret:
  oasis_secrets:
    type: file
    path: $VECTOR_SECRETS

# Data source: macOS Unified Log
sources:
  macos_log:
    type: exec
    mode: scheduled
    scheduled:
      exec_interval_secs: 60
    command:
      - log
      - show
      - --style
      - json
      - --predicate
      - eventType == logEvent OR eventType == activityCreateEvent
      - --last
      - 1m

# Transform: Parse and enrich
transforms:
  parse_macos_log:
    type: remap
    inputs:
      - macos_log
    source: |
      parsed, err = parse_json(.message)
      if err == null {
        .timestamp = parsed.timestamp
        .subsystem = parsed.subsystem
        .category = parsed.category
        .message_text = parsed.eventMessage
        .log_type = parsed.messageType
        .process = parsed.processImagePath
      }
      .host, _ = get_hostname()
      .oasis_tenant = "internal"
      .source_type = "macos_unified_log"

  filter_noise:
    type: filter
    inputs:
      - parse_macos_log
    condition: |
      .subsystem != "com.apple.system.logger" && 
      .log_type != "debug"

# Sink: O.A.S.I.S. Internal Gateway
sinks:
  oasis_gateway:
    type: http
    inputs:
      - filter_noise
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

elif [ "$OS_TYPE" = "Linux" ]; then
  # Linux configuration (YAML - converted from TOML for consistency)
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
fi

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

# Step 7: Create and start service
echo "🚀 Step 7/8: Creating system service..."

if [ "$OS_TYPE" = "Darwin" ]; then
  # macOS: LaunchDaemon
  cat > "$SERVICE_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.vector.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VECTOR_BIN</string>
        <string>--config</string>
        <string>$VECTOR_CONFIG</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/vector.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/vector.log</string>
</dict>
</plist>
EOF
  chmod 644 "$SERVICE_FILE"
  
  # Stop if already running
  launchctl unload "$SERVICE_FILE" 2>/dev/null || true
  
  # Load and start
  launchctl load "$SERVICE_FILE"
  echo "   ✅ LaunchDaemon created and loaded: $SERVICE_FILE"
  
elif [ "$OS_TYPE" = "Linux" ]; then
  # Linux: systemd unit
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
fi
echo ""

# Wait for service to start
echo "⏳ Waiting 5 seconds for service to start..."
sleep 5
echo ""

# Step 8: Verify service is running
echo "🔍 Step 8/8: Verifying service status..."
if [ "$OS_TYPE" = "Darwin" ]; then
  if launchctl list | grep -q "io.vector.agent"; then
    echo "   ✅ Vector service is running"
  else
    echo "   ❌ ERROR: Vector service is not running"
    echo "   Check logs: tail -f /var/log/vector.log"
    exit 1
  fi
elif [ "$OS_TYPE" = "Linux" ]; then
  if systemctl is-active --quiet vector.service; then
    echo "   ✅ Vector service is running"
    systemctl status vector.service --no-pager -l
  else
    echo "   ❌ ERROR: Vector service is not running"
    echo "   Check logs: journalctl -u vector.service -n 50"
    exit 1
  fi
fi
echo ""

# Register agent with O.A.S.I.S.
echo "📝 Registering agent with O.A.S.I.S..."
HOSTNAME=$(hostname)
REGISTRATION_RESPONSE=$(curl -s -X POST "$OASIS_GATEWAY/api/v1/agents/register" \
  -H "Authorization: Bearer $OASIS_API_KEY" \
  -H "Content-Type: application/json" \
  --cacert "$VECTOR_CA_CERT" \
  -d "{\"hostname\":\"$HOSTNAME\",\"agent_type\":\"vector\",\"os_type\":\"$OS_TYPE\",\"os_version\":\"$OS_VERSION\",\"agent_version\":\"$VECTOR_VERSION\"}" \
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
if [ "$OS_TYPE" = "Darwin" ]; then
  echo "     tail -f /var/log/vector.log"
elif [ "$OS_TYPE" = "Linux" ]; then
  echo "     journalctl -u vector.service -f"
fi
echo "  2. Check service status:"
if [ "$OS_TYPE" = "Darwin" ]; then
  echo "     launchctl list | grep vector"
elif [ "$OS_TYPE" = "Linux" ]; then
  echo "     systemctl status vector.service"
fi
echo "  3. Verify logs in O.A.S.I.S. dashboard"
echo ""
echo "To uninstall, run: sudo bash scripts/cleanup-vector.sh"
echo ""
