#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CERT_DIR="$(pwd)"
CA_VALIDITY_DAYS=3650
CERT_VALIDITY_DAYS=365
HOST_IP="192.168.5.32"

echo -e "${BLUE}Generating certificates in: $CERT_DIR${NC}"

# Generate CA
echo -e "${BLUE}Generating Root CA...${NC}"
cd ca
openssl genrsa -out oasis-ca.key 4096 2>/dev/null
chmod 600 oasis-ca.key
openssl req -new -x509 -key oasis-ca.key -out oasis-ca.crt -days $CA_VALIDITY_DAYS \
  -subj "/C=US/ST=California/L=San Francisco/O=O.A.S.I.S./CN=O.A.S.I.S. Root CA" 2>/dev/null
chmod 644 oasis-ca.crt
cp oasis-ca.crt oasis-ca.pem
echo -e "${GREEN}✅ CA generated${NC}"

# Generate Gateway cert
echo -e "${BLUE}Generating Gateway certificate...${NC}"
cd ../gateway
openssl genrsa -out gateway.key 2048 2>/dev/null
chmod 600 gateway.key
openssl req -new -key gateway.key -out gateway.csr \
  -subj "/C=US/ST=California/O=O.A.S.I.S./CN=internal-gateway.oasis-siem.local" 2>/dev/null

cat > san.cnf <<EOF
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

openssl x509 -req -in gateway.csr -CA ../ca/oasis-ca.crt -CAkey ../ca/oasis-ca.key \
  -CAcreateserial -out gateway.crt -days $CERT_VALIDITY_DAYS -extensions v3_req \
  -extfile san.cnf 2>/dev/null
chmod 644 gateway.crt
rm -f gateway.csr san.cnf
echo -e "${GREEN}✅ Gateway certificate generated${NC}"

# Generate Ingestion cert
echo -e "${BLUE}Generating Ingestion certificate...${NC}"
cd ../ingestion
openssl genrsa -out ingestion.key 2048 2>/dev/null
chmod 600 ingestion.key
openssl req -new -key ingestion.key -out ingestion.csr \
  -subj "/C=US/ST=California/O=O.A.S.I.S./CN=ingestion-service.oasis-siem.local" 2>/dev/null

cat > san.cnf <<EOF
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

openssl x509 -req -in ingestion.csr -CA ../ca/oasis-ca.crt -CAkey ../ca/oasis-ca.key \
  -CAcreateserial -out ingestion.crt -days $CERT_VALIDITY_DAYS -extensions v3_req \
  -extfile san.cnf 2>/dev/null
chmod 644 ingestion.crt
rm -f ingestion.csr san.cnf
echo -e "${GREEN}✅ Ingestion certificate generated${NC}"

cd ..
echo ""
echo -e "${BLUE}Verifying certificates...${NC}"
openssl verify -CAfile ca/oasis-ca.crt gateway/gateway.crt
openssl verify -CAfile ca/oasis-ca.crt ingestion/ingestion.crt

echo ""
echo -e "${GREEN}✅ All certificates generated successfully!${NC}"
echo ""
echo "Files created:"
ls -lh ca/ gateway/ ingestion/
