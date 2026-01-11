# O.A.S.I.S. Tenant Configuration

This directory contains tenant-specific configuration for O.A.S.I.S. agent deployment.

## tenant.conf

The `tenant.conf` file contains:
- Gateway connection details (host and port)
- API authentication key
- Tenant UUID
- Embedded CA certificate for TLS verification

## File Locations

### Linux/macOS
```
/etc/oasis/tenant.conf
```

### Windows
```
C:\oasis\tenant.conf
```

## Generating tenant.conf

**From the O.A.S.I.S. Dashboard:**
1. Navigate to **Settings** → **Agents**
2. Click **Generate Agent Config**
3. Download `tenant.conf`
4. Copy to the appropriate location on target system

**Manual Creation:**
Use `tenant.conf.example` as a template:

```bash
# Linux/macOS
sudo mkdir -p /etc/oasis
sudo cp tenant.conf.example /etc/oasis/tenant.conf
sudo chmod 600 /etc/oasis/tenant.conf
sudo chown root:root /etc/oasis/tenant.conf
```

```powershell
# Windows (PowerShell as Administrator)
New-Item -ItemType Directory -Path "C:\oasis" -Force
Copy-Item tenant.conf.example C:\oasis\tenant.conf
icacls "C:\oasis\tenant.conf" /inheritance:r /grant:r "Administrators:F"
```

## Security

- **DO NOT** commit `tenant.conf` to version control
- **DO NOT** share tenant.conf between different tenants
- Store securely with restricted permissions (600 on Unix, Administrators-only on Windows)
- Rotate API keys regularly from the dashboard

## Usage

Once `tenant.conf` is in place, run the deployment script:

```bash
# Linux
sudo ./deploy-fluentbit.sh

# macOS
sudo ./deploy-fluentbit-macos.sh
```

```powershell
# Windows (PowerShell as Administrator)
.\deploy-fluentbit.ps1
```

The deployment script will automatically:
1. Load configuration from `tenant.conf`
2. Validate all required fields
3. Extract and install the CA certificate
4. Configure Fluent Bit with tenant-specific settings
5. Register the agent with O.A.S.I.S.

## Troubleshooting

### "Tenant configuration file not found"
Ensure `tenant.conf` is in the correct location:
- Linux/macOS: `/etc/oasis/tenant.conf`
- Windows: `C:\oasis\tenant.conf`

### "CA certificate not found in tenant.conf"
The certificate must be embedded between these markers:
```
#--- BEGIN OASIS CA CERTIFICATE -----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
#--- END OASIS CA CERTIFICATE ---
```

### "OASIS_GATEWAY_HOST not set"
Ensure the config file contains:
```
OASIS_GATEWAY_HOST=your.gateway.host
OASIS_API_KEY=oasis_pk_...
OASIS_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

##API Key Rotation

To rotate your API key:
1. Generate new key in O.A.S.I.S. Dashboard
2. Update `OASIS_API_KEY` in `tenant.conf`
3. Restart Fluent Bit service:

```bash
# Linux
sudo systemctl restart fluent-bit

# macOS
sudo launchctl unload /Library/LaunchDaemons/io.fluentbit.agent.plist
sudo launchctl load /Library/LaunchDaemons/io.fluentbit.agent.plist
```

```powershell
# Windows
Restart-Service fluent-bit
```
