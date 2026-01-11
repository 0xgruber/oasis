# Fluent Bit Examples for O.A.S.I.S.

This directory contains example Fluent Bit configurations for different use cases with the O.A.S.I.S. platform.

## Available Examples

1. **linux-systemd.conf** - Basic systemd journal collection for Linux
2. **linux-syslog.conf** - Syslog file collection for Linux
3. **linux-production.conf** - Production-ready configuration with multiple inputs
4. **docker-logs.conf** - Docker container log collection
5. **windows-eventlog.conf** - Windows Event Log collection

## Quick Start

### Linux (systemd)

```bash
# Install Fluent Bit
sudo scripts/deploy-fluentbit.sh

# Or use example config directly
sudo cp FLUENTBIT_EXAMPLES/linux-systemd.conf /etc/fluent-bit/fluent-bit.conf
sudo systemctl restart fluent-bit
```

### Docker

```bash
docker run --rm \
  -v $(pwd)/FLUENTBIT_EXAMPLES/docker-logs.conf:/fluent-bit/etc/fluent-bit.conf \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  fluent/fluent-bit:3.0
```

## Configuration Variables

All examples use the following placeholders that must be replaced:

- `${OASIS_GATEWAY_HOST}` - Your O.A.S.I.S. Gateway hostname/IP
- `${OASIS_GATEWAY_PORT}` - Gateway port (default: 8444)
- `${OASIS_API_KEY}` - Your API key from O.A.S.I.S.
- `${OASIS_TENANT_ID}` - Your tenant UUID
- `${OASIS_CA_CERT}` - Path to O.A.S.I.S. CA certificate

## Key Features

### Performance
- **Buffering**: Filesystem-based buffering for reliability
- **Backpressure**: Memory limits to prevent OOM
- **Retries**: Automatic retry on connection failures

### Security
- **TLS/mTLS**: All connections encrypted
- **Certificate validation**: CA certificate verification
- **API key auth**: Bearer token authentication

### Reliability
- **Storage**: Persistent buffering to disk
- **Health checks**: Built-in service monitoring
- **Graceful shutdown**: Clean exit on service stop

## Testing Configuration

Test your configuration before deploying:

```bash
# Dry run (check syntax)
fluent-bit -c /etc/fluent-bit/fluent-bit.conf --dry-run

# Foreground mode (see logs)
fluent-bit -c /etc/fluent-bit/fluent-bit.conf

# Check service status
systemctl status fluent-bit
journalctl -u fluent-bit -f
```

## Performance Tuning

### Low-Resource Systems
```ini
[SERVICE]
    Flush        10           # Increase flush interval
    Log_Level    error        # Reduce logging
    storage.max_chunks_up  32 # Reduce buffer chunks
```

### High-Throughput Systems
```ini
[SERVICE]
    Flush        1            # Decrease flush interval
    Workers      4            # Enable parallel processing
    storage.max_chunks_up  256 # Increase buffer chunks
```

## Troubleshooting

### No logs appearing in O.A.S.I.S.
1. Check Fluent Bit logs: `journalctl -u fluent-bit -f`
2. Verify network connectivity: `curl -k https://${GATEWAY}:8444/health`
3. Test API key: `curl -H "Authorization: Bearer ${API_KEY}" ...`
4. Check CA certificate: `openssl verify -CAfile oasis-ca.pem`

### High memory usage
- Reduce `storage.max_chunks_up`
- Decrease `storage.backlog.mem_limit`
- Increase `Flush` interval

### Connection timeouts
- Verify firewall rules allow port 8444
- Check TLS certificate validity
- Increase `net.keepalive_idle_timeout`

## Support

For issues specific to Fluent Bit configuration, consult:
- Official docs: https://docs.fluentbit.io/
- GitHub: https://github.com/fluent/fluent-bit

For O.A.S.I.S. integration issues:
- GitHub: https://github.com/0xgruber/oasis/issues
