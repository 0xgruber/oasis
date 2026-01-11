#!/bin/bash
###############################################################################
# O.A.S.I.S. Fluent Bit Agent Deployment Script (macOS)
# 
# This script installs and configures Fluent Bit for log collection
# and forwards logs to the O.A.S.I.S. Internal Gateway.
#
# Supports: Intel (x86_64) and Apple Silicon (arm64)
#
# Prerequisites:
#   - macOS 11.0 (Big Sur) or later
#   - Homebrew installed
#   - sudo access
#   - Network connectivity to O.A.S.I.S. Gateway
#   - Valid API key and CA certificate
#
# Usage:
#   sudo ./deploy-fluentbit-macos.sh
#
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/usr/local/etc/fluent-bit"
LOG_DIR="/usr/local/var/log/fluent-bit"
PLIST_NAME="io.fluentbit.agent"
PLIST_PATH="/Library/LaunchDaemons/${PLIST_NAME}.plist"

# O.A.S.I.S. Configuration (Hardcoded)
OASIS_GATEWAY_HOST="192.168.5.32"
OASIS_GATEWAY_PORT="8444"
OASIS_API_KEY="oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"
OASIS_TENANT_ID="ffffffff-ffff-ffff-ffff-ffffffffffff"

# Embedded CA Certificate
read -r -d '' OASIS_CA_CERT << 'EOF'
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

###############################################################################
# Helper Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            log_info "Detected architecture: Intel (x86_64)"
            ;;
        arm64)
            log_info "Detected architecture: Apple Silicon (arm64)"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

check_macos_version() {
    local version=$(sw_vers -productVersion)
    local major=$(echo $version | cut -d. -f1)
    
    log_info "Detected macOS version: $version"
    
    if [ "$major" -lt 11 ]; then
        log_error "This script requires macOS 11.0 (Big Sur) or later"
        exit 1
    fi
}

check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is not installed"
        log_info "Install Homebrew from: https://brew.sh"
        log_info "Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    log_success "Homebrew is installed"
}

show_config() {
    log_info "=== O.A.S.I.S. Configuration ==="
    echo
    echo "  Gateway: $OASIS_GATEWAY_HOST:$OASIS_GATEWAY_PORT"
    echo "  Tenant:  $OASIS_TENANT_ID"
    echo "  API Key: $OASIS_API_KEY"
    echo
}

install_fluent_bit() {
    log_info "Installing Fluent Bit via Homebrew..."
    
    # Update Homebrew
    su - ${SUDO_USER} -c "brew update" || true
    
    # Install or upgrade Fluent Bit
    if su - ${SUDO_USER} -c "brew list fluent-bit &>/dev/null"; then
        log_info "Fluent Bit is already installed, upgrading..."
        su - ${SUDO_USER} -c "brew upgrade fluent-bit" || true
    else
        su - ${SUDO_USER} -c "brew install fluent-bit"
    fi
    
    log_success "Fluent Bit installed successfully"
}

register_agent() {
    log_info "Registering agent with O.A.S.I.S...."
    
    local hostname=$(hostname -s)
    local os_version=$(sw_vers -productVersion)
    local agent_version=$(fluent-bit --version | head -n1 | awk '{print $3}')
    local arch=$(uname -m)
    
    # Write embedded CA certificate to temp file for curl
    local temp_cert=$(mktemp)
    echo "$OASIS_CA_CERT" > "$temp_cert"
    
    # Register agent via API
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://${OASIS_GATEWAY_HOST}:${OASIS_GATEWAY_PORT}/api/v1/agents/register" \
        -H "Authorization: Bearer ${OASIS_API_KEY}" \
        -H "Content-Type: application/json" \
        --cacert "$temp_cert" \
        -d "{
            \"hostname\": \"${hostname}\",
            \"agent_type\": \"fluent-bit\",
            \"os_type\": \"macOS\",
            \"os_version\": \"${os_version}\",
            \"agent_version\": \"${agent_version}\",
            \"metadata\": {
                \"deployment_script\": \"deploy-fluentbit-macos.sh\",
                \"deployment_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                \"architecture\": \"${arch}\"
            }
        }")
    
    # Cleanup temp cert
    rm -f "$temp_cert"
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        log_success "Agent registered successfully"
    else
        log_warning "Agent registration returned HTTP $http_code"
        log_warning "Response: $body"
        log_info "Continuing with deployment..."
    fi
}

create_config() {
    log_info "Creating Fluent Bit configuration..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    # Write embedded CA certificate
    echo "$OASIS_CA_CERT" > "$CONFIG_DIR/oasis-ca.pem"
    chmod 644 "$CONFIG_DIR/oasis-ca.pem"
    log_info "CA certificate written to $CONFIG_DIR/oasis-ca.pem"
    
    # Create main configuration
    cat > "$CONFIG_DIR/fluent-bit.conf" <<EOF
[SERVICE]
    Flush                     5
    Daemon                    Off
    Log_Level                 info
    Log_File                  $LOG_DIR/fluent-bit.log
    Parsers_File              parsers.conf
    storage.path              $LOG_DIR/storage/
    storage.sync              normal
    storage.checksum          off
    storage.max_chunks_up     128
    storage.backlog.mem_limit 50M

# ============================================
# Input: macOS system logs
# ============================================
[INPUT]
    Name                      tail
    Tag                       macos.system
    Path                      /var/log/system.log
    Parser                    syslog-rfc3164
    Read_From_Head            Off
    Refresh_Interval          5
    storage.type              filesystem

# ============================================
# Input: macOS install logs
# ============================================
[INPUT]
    Name                      tail
    Tag                       macos.install
    Path                      /var/log/install.log
    Parser                    syslog-rfc3164
    Read_From_Head            Off
    storage.type              filesystem

# ============================================
# Filter: Add metadata
# ============================================
[FILTER]
    Name                      modify
    Match                     *
    Add                       tenant_id $OASIS_TENANT_ID
    Add                       hostname \${HOSTNAME}
    Add                       source_type macos_log
    Add                       agent_type fluent-bit
    Add                       os_type macOS

# ============================================
# Output: O.A.S.I.S. Internal Gateway
# ============================================
[OUTPUT]
    Name                      http
    Match                     *
    Host                      $OASIS_GATEWAY_HOST
    Port                      $OASIS_GATEWAY_PORT
    URI                       /api/v1/ingest
    Format                    json
    Header                    Authorization Bearer $OASIS_API_KEY
    tls                       On
    tls.verify                On
    tls.ca_file               $CONFIG_DIR/oasis-ca.pem
    Retry_Limit               5
    storage.total_limit_size  500M
    net.keepalive             On
    net.keepalive_idle_timeout 30

EOF
    
    # Create parsers configuration
    cat > "$CONFIG_DIR/parsers.conf" <<EOF
[PARSER]
    Name                      syslog-rfc3164
    Format                    regex
    Regex                     /^<(?<pri>[0-9]+)>(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$/
    Time_Key                  time
    Time_Format               %b %d %H:%M:%S
    Time_Keep                 On

[PARSER]
    Name                      json
    Format                    json
    Time_Key                  time
    Time_Format               %Y-%m-%dT%H:%M:%S.%L
    Time_Keep                 On

EOF
    
    # Create storage directory
    mkdir -p "$LOG_DIR/storage"
    
    # Set permissions
    chmod 755 "$CONFIG_DIR"
    chmod 644 "$CONFIG_DIR/fluent-bit.conf"
    chmod 644 "$CONFIG_DIR/parsers.conf"
    chmod 755 "$LOG_DIR"
    
    log_success "Configuration created at $CONFIG_DIR"
}

create_launchd_service() {
    log_info "Creating launchd service..."
    
    # Stop existing service if running
    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
    fi
    
    # Find fluent-bit binary path
    local fb_bin=$(which fluent-bit)
    
    # Create launchd plist
    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>${fb_bin}</string>
        <string>-c</string>
        <string>${CONFIG_DIR}/fluent-bit.conf</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>${LOG_DIR}</string>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF
    
    # Set permissions
    chmod 644 "$PLIST_PATH"
    chown root:wheel "$PLIST_PATH"
    
    log_success "Launchd service created"
}

start_service() {
    log_info "Starting Fluent Bit service..."
    
    # Load service
    launchctl load "$PLIST_PATH"
    
    # Wait a moment for service to start
    sleep 2
    
    # Check if running
    if launchctl list | grep -q "$PLIST_NAME"; then
        log_success "Fluent Bit service started successfully"
    else
        log_error "Failed to start Fluent Bit service"
        log_info "Check logs at: $LOG_DIR"
        exit 1
    fi
}

print_summary() {
    echo
    log_success "=== Deployment Complete ==="
    echo
    echo "Configuration files:"
    echo "  - Main config:   $CONFIG_DIR/fluent-bit.conf"
    echo "  - Parsers:       $CONFIG_DIR/parsers.conf"
    echo "  - CA cert:       $CONFIG_DIR/oasis-ca.pem"
    echo "  - LaunchDaemon:  $PLIST_PATH"
    echo
    echo "Log files:"
    echo "  - Fluent Bit:    $LOG_DIR/fluent-bit.log"
    echo "  - Stdout:        $LOG_DIR/stdout.log"
    echo "  - Stderr:        $LOG_DIR/stderr.log"
    echo
    echo "Service commands:"
    echo "  - Status:        sudo launchctl list | grep $PLIST_NAME"
    echo "  - Stop:          sudo launchctl unload $PLIST_PATH"
    echo "  - Start:         sudo launchctl load $PLIST_PATH"
    echo "  - Restart:       sudo launchctl unload $PLIST_PATH && sudo launchctl load $PLIST_PATH"
    echo "  - Logs:          tail -f $LOG_DIR/fluent-bit.log"
    echo
    log_info "Logs are now being forwarded to O.A.S.I.S."
    echo
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo
    log_info "=== O.A.S.I.S. Fluent Bit Deployment (macOS) ==="
    echo
    
    check_root
    detect_architecture
    check_macos_version
    check_homebrew
    show_config
    
    install_fluent_bit
    register_agent
    create_config
    create_launchd_service
    start_service
    
    print_summary
}

# Run main function
main
