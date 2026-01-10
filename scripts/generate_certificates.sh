#!/bin/bash
#############################################################################
# O.A.S.I.S. Certificate Generation Script
# Generates self-signed CA and service certificates for TLS/mTLS
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_ROOT/infrastructure/certificates"

# Certificate validity periods
CA_VALIDITY_DAYS=3650    # 10 years
CERT_VALIDITY_DAYS=365   # 1 year

# Certificate subjects
CA_SUBJECT="/C=US/ST=California/L=San Francisco/O=O.A.S.I.S./CN=O.A.S.I.S. Root CA"
GATEWAY_SUBJECT="/C=US/ST=California/O=O.A.S.I.S./CN=internal-gateway.oasis-siem.local"
INGESTION_SUBJECT="/C=US/ST=California/O=O.A.S.I.S./CN=ingestion-service.oasis-siem.local"

# Host IP (update if different)
HOST_IP="192.168.5.32"

#############################################################################
# Functions
#############################################################################

print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_openssl() {
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed"
        echo "Install with: sudo apt install openssl  (Debian/Ubuntu)"
        echo "           or: sudo yum install openssl  (RHEL/CentOS)"
        exit 1
    fi
    print_success "OpenSSL found: $(openssl version)"
}

create_directories() {
    print_header "Creating Directory Structure"
    
    # Create directories with proper ownership
    mkdir -p "$CERT_DIR"/{ca,gateway,ingestion}
    
    print_success "Created directory structure at $CERT_DIR"
}

generate_ca() {
    print_header "Generating Root CA Certificate"
    
    if [[ -f "$CERT_DIR/ca/oasis-ca.crt" ]] && [[ "$1" != "--renew" ]]; then
        print_warning "CA certificate already exists"
        print_warning "Use --renew flag to regenerate"
        return 0
    fi
    
    cd "$CERT_DIR/ca"
    
    # Generate CA private key
    echo "Generating 4096-bit RSA key for CA..."
    openssl genrsa -out oasis-ca.key 4096 2>/dev/null
    chmod 600 oasis-ca.key
    print_success "Generated CA private key"
    
    # Generate self-signed CA certificate
    echo "Generating self-signed CA certificate..."
    openssl req -new -x509 \
        -key oasis-ca.key \
        -out oasis-ca.crt \
        -days $CA_VALIDITY_DAYS \
        -subj "$CA_SUBJECT" \
        2>/dev/null
    chmod 644 oasis-ca.crt
    print_success "Generated CA certificate (valid for $CA_VALIDITY_DAYS days)"
    
    # Create .pem copy for Vector compatibility
    cp oasis-ca.crt oasis-ca.pem
    chmod 644 oasis-ca.pem
    print_success "Created oasis-ca.pem for Vector agents"
    
    # Display CA info
    echo ""
    echo "CA Certificate Information:"
    openssl x509 -in oasis-ca.crt -noout -subject -dates
    echo ""
}

generate_gateway_cert() {
    print_header "Generating Gateway Certificate"
    
    if [[ ! -f "$CERT_DIR/ca/oasis-ca.crt" ]]; then
        print_error "CA certificate not found. Run CA generation first."
        exit 1
    fi
    
    cd "$CERT_DIR/gateway"
    
    # Generate gateway private key
    echo "Generating 2048-bit RSA key for gateway..."
    openssl genrsa -out gateway.key 2048 2>/dev/null
    chmod 600 gateway.key
    print_success "Generated gateway private key"
    
    # Generate CSR
    echo "Generating Certificate Signing Request..."
    openssl req -new \
        -key gateway.key \
        -out gateway.csr \
        -subj "$GATEWAY_SUBJECT" \
        2>/dev/null
    print_success "Generated gateway CSR"
    
    # Create SAN configuration
    cat > gateway-san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = internal-gateway
DNS.2 = external-gateway
DNS.3 = internal-gateway.oasis-siem.local
DNS.4 = external-gateway.oasis-siem.local
DNS.5 = localhost
IP.1 = $HOST_IP
IP.2 = 172.21.0.10
IP.3 = 172.20.0.10
IP.4 = 127.0.0.1
EOF
    
    # Sign certificate with CA
    echo "Signing certificate with CA..."
    openssl x509 -req \
        -in gateway.csr \
        -CA "$CERT_DIR/ca/oasis-ca.crt" \
        -CAkey "$CERT_DIR/ca/oasis-ca.key" \
        -CAcreateserial \
        -out gateway.crt \
        -days $CERT_VALIDITY_DAYS \
        -extensions v3_req \
        -extfile gateway-san.cnf \
        2>/dev/null
    chmod 644 gateway.crt
    print_success "Generated gateway certificate (valid for $CERT_VALIDITY_DAYS days)"
    
    # Cleanup
    rm -f gateway.csr gateway-san.cnf
    
    # Display cert info
    echo ""
    echo "Gateway Certificate Information:"
    openssl x509 -in gateway.crt -noout -subject -dates
    echo ""
    echo "Subject Alternative Names:"
    openssl x509 -in gateway.crt -noout -text | grep -A 10 "Subject Alternative Name"
    echo ""
}

generate_ingestion_cert() {
    print_header "Generating Ingestion Service Certificate"
    
    if [[ ! -f "$CERT_DIR/ca/oasis-ca.crt" ]]; then
        print_error "CA certificate not found. Run CA generation first."
        exit 1
    fi
    
    cd "$CERT_DIR/ingestion"
    
    # Generate ingestion private key
    echo "Generating 2048-bit RSA key for ingestion service..."
    openssl genrsa -out ingestion.key 2048 2>/dev/null
    chmod 600 ingestion.key
    print_success "Generated ingestion private key"
    
    # Generate CSR
    echo "Generating Certificate Signing Request..."
    openssl req -new \
        -key ingestion.key \
        -out ingestion.csr \
        -subj "$INGESTION_SUBJECT" \
        2>/dev/null
    print_success "Generated ingestion CSR"
    
    # Create SAN configuration
    cat > ingestion-san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ingestion-service
DNS.2 = ingestion-service.oasis-siem.local
DNS.3 = localhost
IP.1 = 172.22.0.30
IP.2 = 127.0.0.1
EOF
    
    # Sign certificate with CA
    echo "Signing certificate with CA..."
    openssl x509 -req \
        -in ingestion.csr \
        -CA "$CERT_DIR/ca/oasis-ca.crt" \
        -CAkey "$CERT_DIR/ca/oasis-ca.key" \
        -CAcreateserial \
        -out ingestion.crt \
        -days $CERT_VALIDITY_DAYS \
        -extensions v3_req \
        -extfile ingestion-san.cnf \
        2>/dev/null
    chmod 644 ingestion.crt
    print_success "Generated ingestion certificate (valid for $CERT_VALIDITY_DAYS days)"
    
    # Cleanup
    rm -f ingestion.csr ingestion-san.cnf
    
    # Display cert info
    echo ""
    echo "Ingestion Certificate Information:"
    openssl x509 -in ingestion.crt -noout -subject -dates
    echo ""
    echo "Subject Alternative Names:"
    openssl x509 -in ingestion.crt -noout -text | grep -A 10 "Subject Alternative Name"
    echo ""
}

verify_certificates() {
    print_header "Verifying Certificates"
    
    cd "$CERT_DIR"
    
    # Verify gateway certificate
    echo "Verifying gateway certificate..."
    if openssl verify -CAfile ca/oasis-ca.crt gateway/gateway.crt 2>/dev/null; then
        print_success "Gateway certificate verified"
    else
        print_error "Gateway certificate verification failed"
        exit 1
    fi
    
    # Verify ingestion certificate
    echo "Verifying ingestion certificate..."
    if openssl verify -CAfile ca/oasis-ca.crt ingestion/ingestion.crt 2>/dev/null; then
        print_success "Ingestion certificate verified"
    else
        print_error "Ingestion certificate verification failed"
        exit 1
    fi
    
    echo ""
}

display_summary() {
    print_header "Certificate Generation Summary"
    
    cd "$CERT_DIR"
    
    echo "Files created:"
    echo ""
    echo "CA Certificate:"
    ls -lh ca/
    echo ""
    echo "Gateway Certificate:"
    ls -lh gateway/
    echo ""
    echo "Ingestion Certificate:"
    ls -lh ingestion/
    echo ""
    
    print_success "All certificates generated successfully!"
    echo ""
    print_warning "IMPORTANT SECURITY NOTES:"
    echo "  1. Back up ca/oasis-ca.key securely (needed for certificate renewal)"
    echo "  2. NEVER commit *.key files to version control"
    echo "  3. Private keys have 600 permissions (owner read/write only)"
    echo "  4. Certificates have 644 permissions (world-readable)"
    echo ""
    print_warning "NEXT STEPS:"
    echo "  1. Restart O.A.S.I.S. services: docker compose restart"
    echo "  2. Distribute ca/oasis-ca.pem to Vector agents"
    echo "  3. Update Vector configs with gateway URL: https://$HOST_IP:8444/api/v1/ingest"
    echo ""
    print_warning "Certificate Expiration:"
    echo "  - CA: $(openssl x509 -in ca/oasis-ca.crt -noout -enddate | cut -d= -f2)"
    echo "  - Gateway: $(openssl x509 -in gateway/gateway.crt -noout -enddate | cut -d= -f2)"
    echo "  - Ingestion: $(openssl x509 -in ingestion/ingestion.crt -noout -enddate | cut -d= -f2)"
    echo ""
}

#############################################################################
# Main Execution
#############################################################################

main() {
    print_header "O.A.S.I.S. Certificate Generation"
    echo "Project Root: $PROJECT_ROOT"
    echo "Certificate Directory: $CERT_DIR"
    echo ""
    
    # Check prerequisites
    check_openssl
    
    # Create directory structure
    create_directories
    
    # Generate certificates
    generate_ca "$1"
    generate_gateway_cert
    generate_ingestion_cert
    
    # Verify certificates
    verify_certificates
    
    # Display summary
    display_summary
}

# Handle arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [--renew]"
    echo ""
    echo "Generates TLS certificates for O.A.S.I.S. services"
    echo ""
    echo "Options:"
    echo "  --renew    Regenerate all certificates (overwrites existing)"
    echo "  --help     Show this help message"
    exit 0
fi

# Run main function
main "$1"
