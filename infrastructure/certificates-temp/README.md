# O.A.S.I.S. Certificate Management

This directory contains TLS certificates for securing communication between O.A.S.I.S. services and Vector agents.

## Certificate Hierarchy

```
oasis-ca.crt (Root CA - Self-Signed)
├── gateway.crt (Gateway Services Certificate)
│   ├── Used by: internal-gateway, external-gateway
│   ├── Validity: 365 days
│   └── SAN: DNS:internal-gateway, DNS:external-gateway, IP:192.168.5.32
│
└── ingestion.crt (Ingestion Service Certificate)
    ├── Used by: ingestion-service
    ├── Validity: 365 days
    └── SAN: DNS:ingestion-service, DNS:localhost
```

## Directory Structure

```
certificates/
├── ca/
│   ├── oasis-ca.crt          # Root CA certificate (public, distribute to agents)
│   ├── oasis-ca.key          # Root CA private key (KEEP SECURE!)
│   └── oasis-ca.pem          # Same as .crt, for Vector compatibility
├── gateway/
│   ├── gateway.crt           # Gateway server certificate
│   └── gateway.key           # Gateway private key
├── ingestion/
│   ├── ingestion.crt         # Ingestion service certificate
│   └── ingestion.key         # Ingestion service private key
└── README.md                 # This file
```

## Certificate Specifications

### Root CA Certificate
- **Type**: Self-signed Root Certificate Authority
- **Key Size**: 4096-bit RSA
- **Validity**: 3650 days (10 years)
- **Subject**: `/C=US/ST=California/L=San Francisco/O=O.A.S.I.S./CN=O.A.S.I.S. Root CA`
- **Purpose**: Sign all service certificates
- **Distribution**: Copy `ca/oasis-ca.pem` to Vector agents for server verification

### Gateway Certificate
- **Type**: Server certificate signed by Root CA
- **Key Size**: 2048-bit RSA
- **Validity**: 365 days (1 year)
- **Subject**: `/C=US/ST=California/O=O.A.S.I.S./CN=internal-gateway.oasis-siem.local`
- **SAN Entries**:
  - DNS: `internal-gateway`, `external-gateway`
  - DNS: `internal-gateway.oasis-siem.local`, `external-gateway.oasis-siem.local`
  - IP: `192.168.5.32` (host LAN IP)
  - IP: `172.21.0.10` (internal-gateway Docker IP)
  - IP: `172.20.0.10` (external-gateway Docker IP)
- **Purpose**: TLS termination for gateway services (Vector agent connections)

### Ingestion Certificate
- **Type**: Server certificate signed by Root CA
- **Key Size**: 2048-bit RSA
- **Validity**: 365 days (1 year)
- **Subject**: `/C=US/ST=California/O=O.A.S.I.S./CN=ingestion-service.oasis-siem.local`
- **SAN Entries**:
  - DNS: `ingestion-service`, `localhost`
  - IP: `172.22.0.30` (ingestion-service Docker IP)
- **Purpose**: mTLS server certificate for gateway-to-ingestion communication

## Certificate Generation

Certificates are generated using the script:
```bash
/home/aaron/code/oasis/scripts/generate_certificates.sh
```

To regenerate certificates (e.g., before expiration):
```bash
cd /home/aaron/code/oasis
bash scripts/generate_certificates.sh --renew
docker compose restart internal-gateway external-gateway ingestion-service
```

## Certificate Distribution

### For Vector Agents (Linux/macOS/Windows)

**Copy the CA certificate to agents:**

Linux:
```bash
scp /home/aaron/code/oasis/infrastructure/certificates/ca/oasis-ca.pem user@linux-host:/tmp/
sudo mkdir -p /etc/vector/certs
sudo mv /tmp/oasis-ca.pem /etc/vector/certs/
sudo chmod 644 /etc/vector/certs/oasis-ca.pem
```

macOS:
```bash
scp /home/aaron/code/oasis/infrastructure/certificates/ca/oasis-ca.pem user@macos-host:/tmp/
sudo mkdir -p /usr/local/etc/vector/certs
sudo mv /tmp/oasis-ca.pem /usr/local/etc/vector/certs/
sudo chmod 644 /usr/local/etc/vector/certs/oasis-ca.pem
```

Windows (PowerShell):
```powershell
scp user@oasis-host:/home/aaron/code/oasis/infrastructure/certificates/ca/oasis-ca.pem C:\Temp\
New-Item -ItemType Directory -Path "C:\Program Files\Vector\certs" -Force
Move-Item C:\Temp\oasis-ca.pem "C:\Program Files\Vector\certs\"
```

## Certificate Verification

### Verify CA Certificate
```bash
openssl x509 -in ca/oasis-ca.crt -text -noout | grep -A 2 "Subject:"
```

### Verify Gateway Certificate Signed by CA
```bash
openssl verify -CAfile ca/oasis-ca.crt gateway/gateway.crt
```

### Verify Ingestion Certificate Signed by CA
```bash
openssl verify -CAfile ca/oasis-ca.crt ingestion/ingestion.crt
```

### Check SAN Entries
```bash
openssl x509 -in gateway/gateway.crt -text -noout | grep -A 10 "Subject Alternative Name"
openssl x509 -in ingestion/ingestion.crt -text -noout | grep -A 10 "Subject Alternative Name"
```

### Test HTTPS Connection
```bash
# Test gateway HTTPS (ignore self-signed for testing)
curl -k https://localhost:8444/health

# Test with CA verification
curl --cacert ca/oasis-ca.crt https://192.168.5.32:8444/health
```

## Certificate Renewal Schedule

| Certificate | Issued | Expires | Renewal Due |
|-------------|--------|---------|-------------|
| Root CA | (see file) | +10 years | +9 years |
| Gateway | (see file) | +1 year | +11 months |
| Ingestion | (see file) | +1 year | +11 months |

**Set calendar reminder 30 days before service certificate expiration!**

## Security Notes

1. **NEVER commit private keys to git** - `.gitignore` excludes `*.key` files
2. **Root CA key** (`ca/oasis-ca.key`) is the most sensitive - back up securely
3. **File permissions**:
   - Certificates (`.crt`, `.pem`): `644` (world-readable)
   - Private keys (`.key`): `600` (owner read/write only)
4. **Rotation policy**: Rotate service certificates annually, CA certificate every 5-10 years
5. **Revocation**: If a certificate is compromised, regenerate CA and all certificates

## Troubleshooting

### "certificate verify failed" in Vector logs
- Ensure CA certificate path is correct in Vector config
- Verify CA file is readable: `cat /etc/vector/certs/oasis-ca.pem`
- Check Vector config: `vector validate /etc/vector/vector.toml`

### "SSL certificate problem: self signed certificate in certificate chain"
- Vector agents need the CA certificate to trust the self-signed cert
- Ensure `ca_file` is set in Vector config `[sinks.oasis_gateway.tls]` section

### "SSL: CERTIFICATE_VERIFY_FAILED"
- Gateway certificate might not have correct SAN entries
- Regenerate certificates with correct IP/DNS in SAN
- Or temporarily disable verification: `verify_certificate = false` (NOT for production!)

## References

- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Vector TLS Configuration](https://vector.dev/docs/reference/configuration/sinks/http/#tls)
- [O.A.S.I.S. Architecture](../README.md)
