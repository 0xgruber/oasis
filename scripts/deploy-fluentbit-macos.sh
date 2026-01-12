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
#   - tenant.conf file (from O.A.S.I.S. Dashboard) in same directory as script
#
# Usage:
#   # 1. Download tenant.conf from O.A.S.I.S. Dashboard
#   # 2. Place tenant.conf in same directory as this script
#   # 3. Run:
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
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/usr/local/etc/fluent-bit"
LOG_DIR="/usr/local/var/log/fluent-bit"
PLIST_NAME="io.fluentbit.agent"
PLIST_PATH="/Library/LaunchDaemons/${PLIST_NAME}.plist"
TENANT_CONFIG="/etc/oasis/tenant.conf"

# Tenant Configuration (will be loaded from tenant.conf)
OASIS_GATEWAY_HOST=""
OASIS_GATEWAY_PORT=""
OASIS_API_KEY=""
OASIS_TENANT_ID=""

# CA Certificate (will be extracted from tenant.conf)
OASIS_CA_CERT=""

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

log_debug() {
    echo -e "${GRAY}[DEBUG]${NC} $1"
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

setup_tenant_config() {
    log_info "Setting up tenant configuration..."

    # Check if tenant.conf exists in script directory
    local source_config="$SCRIPT_DIR/tenant.conf"

    if [ ! -f "$source_config" ]; then
        log_error "tenant.conf not found in script directory: $SCRIPT_DIR"
        log_error "Please ensure tenant.conf is in the same directory as this script."
        log_error ""
        log_error "You can generate tenant.conf from the O.A.S.I.S. Dashboard."
        exit 1
    fi

    # Create /etc/oasis directory if it doesn't exist
    if [ ! -d "/etc/oasis" ]; then
        mkdir -p "/etc/oasis"
        log_info "Created directory: /etc/oasis"
    fi

    # Copy tenant.conf to /etc/oasis/
    log_info "Copying tenant.conf to $TENANT_CONFIG..."
    cp "$source_config" "$TENANT_CONFIG"
    chmod 600 "$TENANT_CONFIG"
    log_success "Tenant configuration copied"

    # Read tenant.conf to extract certificate for later use
    OASIS_CA_CERT=$(awk '/-----BEGIN CERTIFICATE-----/, /-----END CERTIFICATE-----/' "$source_config")

    if [ -z "$OASIS_CA_CERT" ]; then
        log_warning "No certificate found in tenant.conf (may be optional)"
    else
        log_success "Certificate found in tenant.conf"
    fi
}

load_tenant_config() {
    log_info "Loading tenant configuration from $TENANT_CONFIG..."
    
    if [ ! -f "$TENANT_CONFIG" ]; then
        log_error "Tenant configuration file not found: $TENANT_CONFIG"
        log_error ""
        log_error "Please create $TENANT_CONFIG with the following content:"
        log_error ""
        log_error "OASIS_GATEWAY_HOST=your.gateway.host"
        log_error "OASIS_GATEWAY_PORT=8444"
        log_error "OASIS_API_KEY=your_api_key"
        log_error "OASIS_TENANT_ID=your_tenant_uuid"
        log_error ""
        log_error "You can generate this file from the O.A.S.I.S. Dashboard."
        exit 1
    fi
    
    # Parse the configuration file (only key=value lines, skip comments and cert)
    while IFS='=' read -r key value; do
        # Skip empty lines, comments, and certificate lines
        if [[ -z "$key" ]] || [[ "$key" =~ ^[[:space:]]*# ]] || [[ "$key" =~ ^----- ]]; then
            continue
        fi
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        # Export the variable
        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            export "$key=$value"
        fi
    done < "$TENANT_CONFIG"
    
    # Validate required variables
    if [ -z "$OASIS_GATEWAY_HOST" ]; then
        log_error "OASIS_GATEWAY_HOST not set in $TENANT_CONFIG"
        exit 1
    fi
    
    if [ -z "$OASIS_API_KEY" ]; then
        log_error "OASIS_API_KEY not set in $TENANT_CONFIG"
        exit 1
    fi
    
    if [ -z "$OASIS_TENANT_ID" ]; then
        log_error "OASIS_TENANT_ID not set in $TENANT_CONFIG"
        exit 1
    fi
    
    # Set default port if not specified
    OASIS_GATEWAY_PORT="${OASIS_GATEWAY_PORT:-8444}"
    
    # Extract CA certificate from config file
    OASIS_CA_CERT=$(sed -n '/#--- BEGIN OASIS CA CERTIFICATE ---/,/#--- END OASIS CA CERTIFICATE ---/p' "$TENANT_CONFIG" | \
                    grep -v "^#" | grep -v "^$")
    
    if [ -z "$OASIS_CA_CERT" ]; then
        log_error "CA certificate not found in $TENANT_CONFIG"
        log_error "Please ensure the certificate is embedded between:"
        log_error "  #--- BEGIN OASIS CA CERTIFICATE ---"
        log_error "  #--- END OASIS CA CERTIFICATE ---"
        exit 1
    fi
    
    log_success "Tenant configuration loaded successfully"
    log_info "  Gateway: $OASIS_GATEWAY_HOST:$OASIS_GATEWAY_PORT"
    log_info "  Tenant:  $OASIS_TENANT_ID"
}

fix_homebrew_permissions() {
    log_info "Checking Homebrew installation and permissions..."

    # Get current user (handle both sudo and non-sudo contexts)
    local current_user=${SUDO_USER:-$(whoami)}

    log_info "Current user: $current_user"
    log_info "Fixing any Homebrew permission issues..."

    # Run brew doctor to check for issues
    if su - ${current_user} -c "brew doctor &> /dev/null" ; then
        log_success "Homebrew installation is healthy"
    else
        log_warning "Homebrew doctor found issues"
        su - ${current_user} -c "brew doctor" || true
    fi

    # Fix common permission issues in Homebrew directories
    log_info "Checking and fixing Homebrew directory permissions..."

    local brew_dirs=(
        "/usr/local"
        "/usr/local/bin"
        "/usr/local/etc"
        "/usr/local/lib"
        "/usr/local/share"
        "/usr/local/share/man"
        "/usr/local/share/man/man8"
    )

    local fixed_count=0
    for dir in "${brew_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local dir_owner=$(stat -f "%u" "$dir" 2>/dev/null || stat -c "%u" "$dir" 2>/dev/null || echo "0")
            local current_uid=$(id -u)
            
            if [ "$dir_owner" != "$current_uid" ] && [ -n "$SUDO_USER" ]; then
                log_info "Fixing ownership of: $dir"
                chown -R ${current_user} "$dir" 2>/dev/null && fixed_count=$((fixed_count + 1))
            fi
        fi
    done

    # Ensure Homebrew can write to its directories
    if [ -f "/usr/local/bin/brew" ] || [ -f "/opt/homebrew/bin/brew" ]; then
        log_success "Homebrew binary found and accessible"
    else
        log_warning "Homebrew binary not found in standard location"
        log_info "You may need to reinstall Homebrew if permission fixes didn't help"
    fi

    if [ $fixed_count -gt 0 ]; then
        log_success "Fixed permissions for $fixed_count directories"
    fi
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

# === ENHANCED SYSTEM INFORMATION COLLECTION ===

get_macos_version() {
    echo "$(sw_vers -productName) $(sw_vers -productVersion)"
}

get_system_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "x86_64 (Intel)" ;;
        arm64) echo "arm64 (Apple Silicon)" ;;
        *) echo "$arch" ;;
    esac
}

get_all_mac_addresses() {
    ifconfig -a | grep -E "ether " | while read line; do
        iface=$(echo $line | awk '{print $1}')
        mac=$(echo $line | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
        echo "$iface: $mac"
    done
}

get_network_interfaces() {
    ifconfig -a | grep -E "^[a-zA-Z0-9]+:" | awk '{print $1}' | tr -d ':'
}

register_agent() {
    log_info "Registering agent with O.A.S.I.S...."

    local hostname=$(hostname -s)
    local os_version=$(get_macos_version)
    local agent_version=$(fluent-bit --version | head -n1 | awk '{print $3}')

    local arch=$(get_system_arch)
    local mac_addresses=$(get_all_mac_addresses | tr '\n' ';' | sed 's/;$//')
    local interfaces=$(get_network_interfaces | tr '\n' ',' | sed 's/,$//')

    local metadata="{
        \"deployment_script\": \"deploy-fluentbit-macos.sh\",
        \"deployment_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"architecture\": \"${arch}\",
        \"mac_addresses\": \"${mac_addresses}\",
        \"network_interfaces\": \"${interfaces}\"
    }"

    log_debug "OS Version: ${os_version}"
    log_debug "Architecture: ${arch}"

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
            \"metadata\": ${metadata}
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
    setup_tenant_config
    load_tenant_config
    fix_homebrew_permissions
    install_fluent_bit
    register_agent
    create_config
    create_launchd_service
    start_service
    
    print_summary
}

# Run main function
main
