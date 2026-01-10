#!/bin/bash
# Vector Agent Deployment Script for macOS
# Deploys Vector as a system-level daemon with TLS to O.A.S.I.S.

set -e

# Configuration
OASIS_GATEWAY="192.168.5.32:8444"
OASIS_API_KEY="oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"
CA_CERT_URL="http://192.168.5.32:8000/api/v1/ca-cert"  # You could host this via API

# Colors for output
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== O.A.S.I.S. Vector Agent Deployment ===${NC}"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    VECTOR_ETC="/opt/homebrew/etc/vector"
    VECTOR_LOG="/opt/homebrew/var/log"
    VECTOR_DATA="/opt/homebrew/var/lib/vector"
else
    VECTOR_ETC="/usr/local/etc/vector"
    VECTOR_LOG="/usr/local/var/log"
    VECTOR_DATA="/usr/local/var/lib/vector"
fi

echo "Detected architecture: $ARCH"
echo "Vector config path: $VECTOR_ETC"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run with sudo${NC}"
    echo "Usage: sudo ./deploy-vector-macos.sh"
    exit 1
fi

# Step 1: Install Vector via Homebrew
echo -e "\n${YELLOW}Step 1: Installing Vector...${NC}"
if ! command -v vector &> /dev/null; then
    sudo -u $(logname) brew tap vectordotdev/brew
    sudo -u $(logname) brew install vector
    echo -e "${GREEN}✓ Vector installed${NC}"
else
    echo -e "${GREEN}✓ Vector already installed${NC}"
fi

# Step 2: Create directories
echo -e "\n${YELLOW}Step 2: Creating directories...${NC}"
mkdir -p "$VECTOR_ETC/certs"
mkdir -p "$VECTOR_LOG"
mkdir -p "$VECTOR_DATA"
chmod 755 "$VECTOR_ETC"
chmod 755 "$VECTOR_DATA"
chmod 755 "$VECTOR_LOG"
echo -e "${GREEN}✓ Directories created${NC}"

# Step 3: Download CA certificate
echo -e "\n${YELLOW}Step 3: Installing O.A.S.I.S. CA certificate...${NC}"
# For now, we'll prompt user to provide it
if [ ! -f "$VECTOR_ETC/certs/oasis-ca.pem" ]; then
    echo "Please provide the path to oasis-ca.pem:"
    read -r CA_CERT_PATH
    if [ -f "$CA_CERT_PATH" ]; then
        cp "$CA_CERT_PATH" "$VECTOR_ETC/certs/oasis-ca.pem"
        chmod 644 "$VECTOR_ETC/certs/oasis-ca.pem"
        echo -e "${GREEN}✓ CA certificate installed${NC}"
    else
        echo -e "${RED}Error: CA certificate not found at $CA_CERT_PATH${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ CA certificate already exists${NC}"
fi

# Step 4: Deploy Vector configuration
echo -e "\n${YELLOW}Step 4: Deploying Vector configuration...${NC}"
cat > "$VECTOR_ETC/vector.yaml" <<EOF
# O.A.S.I.S. Vector Agent Configuration
# Auto-generated on $(date)

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

sinks:
  oasis_gateway:
    type: http
    inputs:
      - filter_noise
    uri: https://${OASIS_GATEWAY}/api/v1/ingest
    method: post
    compression: gzip
    encoding:
      codec: json
    batch:
      max_bytes: 1048576
      timeout_secs: 5
    
    request:
      headers:
        Authorization: "Bearer ${OASIS_API_KEY}"
        Content-Type: "application/json"
    
    tls:
      ca_file: ${VECTOR_ETC}/certs/oasis-ca.pem
      verify_certificate: true
      verify_hostname: true
    
    buffer:
      type: disk
      max_size: 268435488
      when_full: block
EOF

chmod 644 "$VECTOR_ETC/vector.yaml"
echo -e "${GREEN}✓ Configuration deployed${NC}"

# Step 5: Validate configuration
echo -e "\n${YELLOW}Step 5: Validating configuration...${NC}"
if vector validate "$VECTOR_ETC/vector.yaml"; then
    echo -e "${GREEN}✓ Configuration valid${NC}"
else
    echo -e "${RED}Error: Configuration validation failed${NC}"
    exit 1
fi

# Step 6: Stop any existing user-level Vector service
echo -e "\n${YELLOW}Step 6: Stopping user-level Vector service...${NC}"
sudo -u $(logname) brew services stop vector 2>/dev/null || true
echo -e "${GREEN}✓ User-level service stopped${NC}"

# Step 7: Start Vector as system-level daemon
echo -e "\n${YELLOW}Step 7: Starting Vector as system daemon...${NC}"
brew services start vector
sleep 3

# Check if Vector is running
if pgrep -x vector > /dev/null; then
    echo -e "${GREEN}✓ Vector is running as system daemon${NC}"
else
    echo -e "${RED}Error: Vector failed to start${NC}"
    echo "Check logs: tail -50 $VECTOR_LOG/vector.log"
    exit 1
fi

# Step 8: Verify logs
echo -e "\n${YELLOW}Step 8: Checking Vector logs...${NC}"
sleep 5
tail -20 "$VECTOR_LOG/vector.log"

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "Vector is now running as a system-level daemon."
echo -e "It will automatically start on boot."
echo -e "\nUseful commands:"
echo -e "  Status:  sudo brew services list"
echo -e "  Logs:    tail -f $VECTOR_LOG/vector.log"
echo -e "  Restart: sudo brew services restart vector"
echo -e "  Stop:    sudo brew services stop vector"
