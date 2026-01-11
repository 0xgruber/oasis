#!/bin/bash
###############################################################################
# O.A.S.I.S. Fluent Bit Agent Deployment Script (Linux)
# 
# This script installs and configures Fluent Bit for log collection
# and forwards logs to the O.A.S.I.S. Internal Gateway.
#
# Supported Distributions:
#   - Debian 12 & 13
#   - Ubuntu 22.04 LTS and above
#   - RHEL/Rocky/Alma 9.7+, 10.1+
#   - CentOS Stream
#   - Fedora 40+
#   - openSUSE Tumbleweed & Leap 15+
#
# Prerequisites:
#   - Root/sudo access
#   - Network connectivity to O.A.S.I.S. Gateway
#   - Valid API key and CA certificate
#
# Usage:
#   sudo ./deploy-fluentbit.sh
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
FLUENT_BIT_VERSION="3.0.3"
INSTALL_DIR="/opt/fluent-bit"
CONFIG_DIR="/etc/fluent-bit"
LOG_DIR="/var/log/fluent-bit"
SERVICE_NAME="fluent-bit"
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
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
    
    # Extract CA certificate from config file (preserve exact PEM format)
    OASIS_CA_CERT=$(sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$TENANT_CONFIG")
    
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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_VERSION_ID=$VERSION_ID
        OS_PRETTY_NAME="$PRETTY_NAME"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
    
    log_info "Detected OS: $OS_PRETTY_NAME"
    
    # Normalize OS names for package management
    case $OS in
        rocky|almalinux)
            OS_FAMILY="rhel"
            ;;
        centos)
            OS_FAMILY="centos"
            ;;
        rhel)
            OS_FAMILY="rhel"
            ;;
        fedora)
            OS_FAMILY="fedora"
            ;;
        debian)
            OS_FAMILY="debian"
            ;;
        ubuntu)
            OS_FAMILY="ubuntu"
            ;;
        opensuse*|sles)
            OS_FAMILY="suse"
            ;;
        *)
            OS_FAMILY=$OS
            ;;
    esac
    
    log_info "OS Family: $OS_FAMILY"
    
    # Validate minimum version requirements
    validate_os_version
}

validate_os_version() {
    local version_ok=true
    local min_version=""
    
    case $OS in
        debian)
            min_version="12"
            if [ "${OS_VERSION_ID%%.*}" -lt 12 ]; then
                version_ok=false
            fi
            ;;
        ubuntu)
            min_version="22.04"
            if [[ "$(echo -e "${OS_VERSION}\n22.04" | sort -V | head -n1)" != "22.04" ]]; then
                version_ok=false
            fi
            ;;
        rhel|rocky|almalinux)
            min_version="9.7"
            # Accept version 9.7+ or 10.1+
            local major="${OS_VERSION_ID%%.*}"
            if [ "$major" -eq 9 ]; then
                local minor="${OS_VERSION_ID#*.}"
                if [ "${minor%%.*}" -lt 7 ]; then
                    version_ok=false
                fi
            elif [ "$major" -lt 9 ]; then
                version_ok=false
            fi
            ;;
        fedora)
            min_version="40"
            if [ "$OS_VERSION_ID" -lt 40 ]; then
                version_ok=false
            fi
            ;;
        opensuse-leap)
            min_version="15"
            if [ "${OS_VERSION_ID%%.*}" -lt 15 ]; then
                version_ok=false
            fi
            ;;
        opensuse-tumbleweed)
            # Rolling release, always supported
            ;;
        centos)
            # Only CentOS Stream is supported
            if [[ ! "$OS_PRETTY_NAME" =~ "Stream" ]]; then
                log_error "Only CentOS Stream is supported. CentOS Linux has reached EOL."
                log_info "Consider migrating to Rocky Linux or AlmaLinux"
                exit 1
            fi
            ;;
    esac
    
    if [ "$version_ok" = false ]; then
        log_warning "This OS version ($OS_VERSION) may not be officially supported"
        log_warning "Minimum recommended version: $min_version"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in curl wget systemctl; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Installing dependencies..."
        
        case $OS_FAMILY in
            ubuntu|debian)
                apt-get update
                apt-get install -y curl wget systemd
                ;;
            rhel|centos|fedora)
                if command -v dnf &> /dev/null; then
                    dnf install -y curl wget systemd
                else
                    yum install -y curl wget systemd
                fi
                ;;
            suse)
                zypper refresh
                zypper install -y curl wget systemd
                ;;
            *)
                log_error "Unsupported OS for automatic dependency installation"
                exit 1
                ;;
        esac
    fi
    
    log_success "All dependencies present"
}

install_fluent_bit() {
    log_info "Installing Fluent Bit $FLUENT_BIT_VERSION..."
    
    case $OS_FAMILY in
        ubuntu)
            # Detect Ubuntu codename
            local codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
            
            # Add Fluent Bit GPG key
            curl -fsSL https://packages.fluentbit.io/fluentbit.key | gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg
            
            # Add Fluent Bit repository
            echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$codename $codename main" | tee /etc/apt/sources.list.d/fluent-bit.list
            
            # Update and install
            apt-get update
            apt-get install -y fluent-bit
            ;;
            
        debian)
            # Detect Debian codename
            local codename=$(lsb_release -cs 2>/dev/null || grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
            
            # Add Fluent Bit GPG key
            curl -fsSL https://packages.fluentbit.io/fluentbit.key | gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg
            
            # Add Fluent Bit repository
            echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/debian/$codename $codename main" | tee /etc/apt/sources.list.d/fluent-bit.list
            
            # Update and install
            apt-get update
            apt-get install -y fluent-bit
            ;;
            
        rhel|centos)
            # Determine major version
            local major_version="${OS_VERSION_ID%%.*}"
            
            # Add Fluent Bit repository
            cat > /etc/yum.repos.d/fluent-bit.repo <<EOF
[fluent-bit]
name=Fluent Bit
baseurl=https://packages.fluentbit.io/centos/${major_version}/\$basearch/
gpgcheck=1
gpgkey=https://packages.fluentbit.io/fluentbit.key
enabled=1
EOF
            
            # Install using dnf or yum
            if command -v dnf &> /dev/null; then
                dnf install -y fluent-bit
            else
                yum install -y fluent-bit
            fi
            ;;
            
        fedora)
            # Fedora uses dnf
            # Add Fluent Bit repository (use Fedora-specific repo if available, otherwise CentOS)
            cat > /etc/yum.repos.d/fluent-bit.repo <<EOF
[fluent-bit]
name=Fluent Bit
baseurl=https://packages.fluentbit.io/centos/9/\$basearch/
gpgcheck=1
gpgkey=https://packages.fluentbit.io/fluentbit.key
enabled=1
EOF
            
            dnf install -y fluent-bit
            ;;
            
        suse)
            # openSUSE uses zypper
            log_info "Adding Fluent Bit repository for openSUSE..."
            
            # Import GPG key
            rpm --import https://packages.fluentbit.io/fluentbit.key
            
            # Determine version for repo URL
            local repo_version
            if [ "$OS" = "opensuse-tumbleweed" ]; then
                repo_version="tumbleweed"
            else
                repo_version="leap/${OS_VERSION_ID}"
            fi
            
            # Add repository
            zypper addrepo -f "https://packages.fluentbit.io/opensuse/${repo_version}/" fluent-bit
            
            # Refresh and install
            zypper refresh
            zypper install -y fluent-bit
            ;;
            
        *)
            log_error "Unsupported OS: $OS ($OS_FAMILY)"
            log_info "Please install Fluent Bit manually from: https://docs.fluentbit.io/manual/installation/linux"
            log_info "Supported distributions:"
            log_info "  - Debian 12+"
            log_info "  - Ubuntu 22.04+"
            log_info "  - RHEL/Rocky/Alma 9.7+, 10.1+"
            log_info "  - CentOS Stream"
            log_info "  - Fedora 40+"
            log_info "  - openSUSE Tumbleweed & Leap 15+"
            exit 1
            ;;
    esac
    
    log_success "Fluent Bit installed successfully"
}

register_agent() {
    log_info "Registering agent with O.A.S.I.S...."
    
    local hostname=$(hostname)
    local os_type="Linux"
    local os_version="$OS $OS_VERSION"
    local agent_version=$(fluent-bit --version | head -n1 | awk '{print $3}')
    
    # Write CA cert temporarily for registration
    local temp_ca="/tmp/oasis-ca-$$.pem"
    echo "$OASIS_CA_CERT" > "$temp_ca"
    
    # Register agent via API
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://${OASIS_GATEWAY_HOST}:${OASIS_GATEWAY_PORT}/api/v1/agents/register" \
        -H "Authorization: Bearer ${OASIS_API_KEY}" \
        -H "Content-Type: application/json" \
        --cacert "$temp_ca" \
        -d "{
            \"hostname\": \"${hostname}\",
            \"agent_type\": \"fluent-bit\",
            \"os_type\": \"${os_type}\",
            \"os_version\": \"${os_version}\",
            \"agent_version\": \"${agent_version}\",
            \"metadata\": {
                \"deployment_script\": \"deploy-fluentbit.sh\",
                \"deployment_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
            }
        }")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Cleanup temp CA cert
    rm -f "$temp_ca"
    
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
    
    # Write embedded CA certificate to disk
    echo "$OASIS_CA_CERT" > "$CONFIG_DIR/oasis-ca.pem"
    chmod 644 "$CONFIG_DIR/oasis-ca.pem"
    
    # Validate certificate format
    if ! openssl x509 -in "$CONFIG_DIR/oasis-ca.pem" -noout 2>/dev/null; then
        log_error "Invalid CA certificate format"
        log_error "Certificate validation failed. Please check the certificate in $TENANT_CONFIG"
        cat "$CONFIG_DIR/oasis-ca.pem"
        exit 1
    fi
    
    log_success "CA certificate written to $CONFIG_DIR/oasis-ca.pem"
    
    # Create main configuration
    cat > "$CONFIG_DIR/fluent-bit.conf" <<EOF
[SERVICE]
    Flush                     5
    Daemon                    Off
    Log_Level                 info
    Log_File                  $LOG_DIR/fluent-bit.log
    Parsers_File              parsers.conf
    storage.path              /var/lib/fluent-bit/
    storage.sync              normal
    storage.checksum          off
    storage.max_chunks_up     128
    storage.backlog.mem_limit 50M

# ============================================
# Input: systemd journal logs
# ============================================
[INPUT]
    Name                      systemd
    Tag                       host.systemd
    Read_From_Tail            On
    Strip_Underscores         On
    Lowercase                 On
    storage.type              filesystem

# ============================================
# Input: syslog file
# ============================================
[INPUT]
    Name                      tail
    Path                      /var/log/syslog
    Tag                       host.syslog
    Read_from_Head            Off
    storage.type              filesystem

# ============================================
# Filter: Add metadata
# ============================================
[FILTER]
    Name                      modify
    Match                     *
    Add                       tenant_id $OASIS_TENANT_ID
    Add                       source \${HOSTNAME}

# ============================================
# Output: O.A.S.I.S. Gateway
# ============================================
[OUTPUT]
    Name                      http
    Match                     *
    Host                      $OASIS_GATEWAY_HOST
    Port                      $OASIS_GATEWAY_PORT
    URI                       /api/v1/ingest
    Format                    json
    json_date_key             date
    json_date_format          epoch
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
    Name                      syslog-rfc5424
    Format                    regex
    Regex                     /^\<(?<pri>[0-9]{1,5})\>1 (?<time>[^ ]+) (?<host>[^ ]+) (?<ident>[^ ]+) (?<pid>[-0-9]+) (?<msgid>[^ ]+) (?<extradata>(\[.*\]|-)) (?<message>.+)$/
    Time_Key                  time
    Time_Format               %Y-%m-%dT%H:%M:%S.%L%z
    Time_Keep                 On

[PARSER]
    Name                      json
    Format                    json
    Time_Key                  time
    Time_Format               %Y-%m-%dT%H:%M:%S.%L
    Time_Keep                 On

EOF
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    mkdir -p /var/lib/fluent-bit
    
    # Set permissions
    chmod 644 "$CONFIG_DIR/fluent-bit.conf"
    chmod 644 "$CONFIG_DIR/parsers.conf"
    chmod 755 "$LOG_DIR"
    chmod 755 /var/lib/fluent-bit
    
    log_success "Configuration created at $CONFIG_DIR"
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=Fluent Bit - Log Forwarder for O.A.S.I.S.
Documentation=https://docs.fluentbit.io/manual/
After=network.target

[Service]
Type=simple
ExecStart=/opt/fluent-bit/bin/fluent-bit -c $CONFIG_DIR/fluent-bit.conf
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=fluent-bit

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR /var/lib/fluent-bit
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target

EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Systemd service created"
}

validate_fluent_bit_config() {
    log_info "Validating Fluent Bit configuration..."
    
    # Check if fluent-bit binary exists
    local fb_bin="/opt/fluent-bit/bin/fluent-bit"
    if [ ! -f "$fb_bin" ]; then
        log_warning "Fluent Bit binary not found at $fb_bin, skipping validation"
        return 0
    fi
    
    # Test configuration with dry-run
    if "$fb_bin" -c "$CONFIG_DIR/fluent-bit.conf" --dry-run 2>&1 | tee /tmp/fluent-bit-validation.log; then
        log_success "Fluent Bit configuration is valid"
        return 0
    else
        log_error "Fluent Bit configuration validation failed"
        log_error "Validation output:"
        cat /tmp/fluent-bit-validation.log
        exit 1
    fi
}

start_service() {
    log_info "Starting Fluent Bit service..."
    
    # Enable service to start on boot
    systemctl enable "$SERVICE_NAME"
    
    # Start service
    systemctl start "$SERVICE_NAME"
    
    # Wait a moment for service to start
    sleep 2
    
    # Check status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Fluent Bit service started successfully"
        systemctl status "$SERVICE_NAME" --no-pager
    else
        log_error "Failed to start Fluent Bit service"
        echo
        log_error "=== Service Status ==="
        systemctl status "$SERVICE_NAME" --no-pager || true
        echo
        log_error "=== Recent Logs ==="
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager || true
        echo
        log_error "=== Manual Troubleshooting ==="
        log_info "Try running Fluent Bit manually to see the error:"
        log_info "  sudo /opt/fluent-bit/bin/fluent-bit -c $CONFIG_DIR/fluent-bit.conf -v"
        echo
        log_info "Check certificate validity:"
        log_info "  sudo openssl x509 -in $CONFIG_DIR/oasis-ca.pem -text -noout"
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
    echo
    echo "Log files:"
    echo "  - Fluent Bit:    $LOG_DIR/fluent-bit.log"
    echo "  - Systemd:       journalctl -u $SERVICE_NAME -f"
    echo
    echo "Service commands:"
    echo "  - Status:        systemctl status $SERVICE_NAME"
    echo "  - Start:         systemctl start $SERVICE_NAME"
    echo "  - Stop:          systemctl stop $SERVICE_NAME"
    echo "  - Restart:       systemctl restart $SERVICE_NAME"
    echo "  - Logs:          journalctl -u $SERVICE_NAME -f"
    echo
    log_info "Logs are now being forwarded to O.A.S.I.S."
    echo
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo
    log_info "=== O.A.S.I.S. Fluent Bit Deployment ==="
    echo
    
    check_root
    load_tenant_config
    detect_os
    validate_os_version
    
    install_fluent_bit
    register_agent
    create_config
    validate_fluent_bit_config
    create_systemd_service
    start_service
    
    print_summary
}

# Run main function
main
