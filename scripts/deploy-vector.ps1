# O.A.S.I.S. Vector Agent Deployment Script (Windows)
# 
# This script:
# 1. Installs Vector using MSI installer
# 2. Deploys configuration, secrets, and CA certificate
# 3. Creates Windows Service
# 4. Registers agent with O.A.S.I.S.
# 
# Usage: Run PowerShell as Administrator, then:
#        .\scripts\deploy-vector.ps1

#Requires -RunAsAdministrator

# Configuration
$OASIS_GATEWAY = "https://192.168.5.32:8444"
$OASIS_API_KEY = "oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"
$VECTOR_VERSION = "0.43.0"  # Update as needed

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "O.A.S.I.S. Vector Agent Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Detect system info
$OS_VERSION = (Get-CimInstance Win32_OperatingSystem).Version
$ARCH = (Get-CimInstance Win32_OperatingSystem).OSArchitecture

Write-Host "🔍 Detected System:" -ForegroundColor Yellow
Write-Host "   OS: Windows $OS_VERSION"
Write-Host "   Architecture: $ARCH"
Write-Host ""

# Set paths
$VECTOR_INSTALL_DIR = "$env:ProgramFiles\Vector"
$VECTOR_BIN = "$VECTOR_INSTALL_DIR\bin\vector.exe"
$VECTOR_CONFIG_DIR = "$env:ProgramData\Vector\config"
$VECTOR_CONFIG = "$VECTOR_CONFIG_DIR\vector.yaml"
$VECTOR_SECRETS = "$VECTOR_CONFIG_DIR\secrets.json"
$VECTOR_CERTS_DIR = "$VECTOR_CONFIG_DIR\certs"
$VECTOR_CA_CERT = "$VECTOR_CERTS_DIR\oasis-ca.pem"
$VECTOR_DATA_DIR = "$env:ProgramData\Vector\data"
$VECTOR_LOG_DIR = "$env:ProgramData\Vector\logs"
$TEMP_DIR = "$env:TEMP\vector-installer"

Write-Host "📁 Installation Paths:" -ForegroundColor Yellow
Write-Host "   Install Dir: $VECTOR_INSTALL_DIR"
Write-Host "   Binary: $VECTOR_BIN"
Write-Host "   Config: $VECTOR_CONFIG"
Write-Host "   Secrets: $VECTOR_SECRETS"
Write-Host "   CA Cert: $VECTOR_CA_CERT"
Write-Host "   Data: $VECTOR_DATA_DIR"
Write-Host "   Logs: $VECTOR_LOG_DIR"
Write-Host ""

# Step 1: Install Vector
Write-Host "📦 Step 1/8: Installing Vector..." -ForegroundColor Yellow

if (Test-Path $VECTOR_BIN) {
    $existingVersion = & $VECTOR_BIN --version 2>$null | Select-String -Pattern "vector (\d+\.\d+\.\d+)" | ForEach-Object { $_.Matches.Groups[1].Value }
    Write-Host "   ⚠️  Vector already installed: $existingVersion" -ForegroundColor Yellow
    $reinstall = Read-Host "   Reinstall? (y/N)"
    if ($reinstall -ne "y" -and $reinstall -ne "Y") {
        $skipInstall = $true
    }
}

if (-not $skipInstall) {
    Write-Host "   📥 Downloading Vector $VECTOR_VERSION MSI installer..." -ForegroundColor Cyan
    
    # Determine architecture for MSI download
    if ($ARCH -like "*64*") {
        $MSI_ARCH = "x64"
    } else {
        $MSI_ARCH = "x86"
    }
    
    $MSI_URL = "https://packages.timber.io/vector/$VECTOR_VERSION/vector-$VECTOR_VERSION-$MSI_ARCH.msi"
    $MSI_FILE = "$TEMP_DIR\vector-$VECTOR_VERSION-$MSI_ARCH.msi"
    
    # Create temp directory
    New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null
    
    try {
        # Download MSI
        Write-Host "   Downloading from: $MSI_URL" -ForegroundColor Gray
        Invoke-WebRequest -Uri $MSI_URL -OutFile $MSI_FILE -UseBasicParsing
        
        Write-Host "   📦 Installing Vector..." -ForegroundColor Cyan
        # Install MSI silently
        $installArgs = @(
            "/i"
            "`"$MSI_FILE`""
            "/qn"
            "/norestart"
            "/L*v"
            "`"$TEMP_DIR\vector-install.log`""
        )
        
        $process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            Write-Host "   ❌ ERROR: MSI installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            Write-Host "   Check log: $TEMP_DIR\vector-install.log" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "   ✅ Vector installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ ERROR: Failed to download or install Vector" -ForegroundColor Red
        Write-Host "   $_" -ForegroundColor Red
        exit 1
    }
}

# Verify installation
if (-not (Test-Path $VECTOR_BIN)) {
    Write-Host "   ❌ ERROR: Vector binary not found at $VECTOR_BIN" -ForegroundColor Red
    Write-Host "   Installation may have failed or used a different path." -ForegroundColor Red
    exit 1
}

$VECTOR_VERSION_INSTALLED = & $VECTOR_BIN --version 2>$null | Select-String -Pattern "vector (\d+\.\d+\.\d+)" | ForEach-Object { $_.Matches.Groups[1].Value }
Write-Host "   ✅ Vector installed: $VECTOR_VERSION_INSTALLED" -ForegroundColor Green
Write-Host "   ✅ Vector binary: $VECTOR_BIN" -ForegroundColor Green
Write-Host ""

# Step 2: Create directories
Write-Host "📁 Step 2/8: Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $VECTOR_CONFIG_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $VECTOR_CERTS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $VECTOR_DATA_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $VECTOR_LOG_DIR | Out-Null
Write-Host "   ✅ Directories created" -ForegroundColor Green
Write-Host ""

# Step 3: Deploy secrets file
Write-Host "🔐 Step 3/8: Deploying secrets file..." -ForegroundColor Yellow
$secretsContent = @{
    oasis_api_key = $OASIS_API_KEY
} | ConvertTo-Json

Set-Content -Path $VECTOR_SECRETS -Value $secretsContent -NoNewline

# Set restrictive permissions (only SYSTEM and Administrators)
$acl = Get-Acl $VECTOR_SECRETS
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null

$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$acl.AddAccessRule($systemRule)
$acl.AddAccessRule($adminRule)
Set-Acl -Path $VECTOR_SECRETS -AclObject $acl

Write-Host "   ✅ Secrets file deployed: $VECTOR_SECRETS (restricted permissions)" -ForegroundColor Green
Write-Host ""

# Step 4: Deploy CA certificate
Write-Host "🔒 Step 4/8: Deploying O.A.S.I.S. CA certificate..." -ForegroundColor Yellow
$caCert = @"
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
"@

Set-Content -Path $VECTOR_CA_CERT -Value $caCert
Write-Host "   ✅ CA certificate deployed: $VECTOR_CA_CERT" -ForegroundColor Green
Write-Host ""

# Step 5: Deploy Vector configuration
Write-Host "⚙️  Step 5/8: Deploying Vector configuration..." -ForegroundColor Yellow

$vectorConfig = @"
# Vector Configuration: Windows Event Log - PRODUCTION
# Managed by O.A.S.I.S. deployment script
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Secrets backend
secret:
  oasis_secrets:
    type: file
    path: "$($VECTOR_SECRETS -replace '\\', '\\')"

# Data source: Windows Event Log
sources:
  windows_events:
    type: windows_event_log
    channels:
      - Application
      - System
      - Security

# Transform: Enrich and filter
transforms:
  enrich_events:
    type: remap
    inputs:
      - windows_events
    source: |
      .host, _ = get_hostname()
      .oasis_tenant = "internal"
      .timestamp = to_unix_timestamp(now())
      .source_type = "windows_event_log"
      .severity = .Level
      .channel = .Channel
      .event_id = .EventID
      .message = .Message

  filter_severity:
    type: filter
    inputs:
      - enrich_events
    condition: 'to_int(.Level) <= 4'

# Sink: O.A.S.I.S. Internal Gateway
sinks:
  oasis_gateway:
    type: http
    inputs:
      - filter_severity
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
      ca_file: "$($VECTOR_CA_CERT -replace '\\', '\\')"
      verify_certificate: true
      verify_hostname: true
    buffer:
      type: disk
      max_size: 268435488
      when_full: block
"@

Set-Content -Path $VECTOR_CONFIG -Value $vectorConfig
Write-Host "   ✅ Configuration deployed: $VECTOR_CONFIG" -ForegroundColor Green
Write-Host ""

# Step 6: Validate configuration
Write-Host "✔️  Step 6/8: Validating configuration..." -ForegroundColor Yellow
try {
    $validateOutput = & $VECTOR_BIN validate --config $VECTOR_CONFIG 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Configuration is valid" -ForegroundColor Green
    } else {
        Write-Host "   ❌ ERROR: Configuration validation failed" -ForegroundColor Red
        Write-Host "   $validateOutput" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "   ❌ ERROR: Configuration validation failed" -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 7: Create and start Windows Service
Write-Host "🚀 Step 7/8: Creating Windows Service..." -ForegroundColor Yellow

# Stop existing service if running
$existingService = Get-Service -Name "Vector" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "   Stopping existing Vector service..." -ForegroundColor Gray
    Stop-Service -Name "Vector" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Install Vector as Windows Service
Write-Host "   Installing Vector Windows Service..." -ForegroundColor Cyan
$installArgs = @(
    "service"
    "install"
    "--config"
    "`"$VECTOR_CONFIG`""
)

$process = Start-Process -FilePath $VECTOR_BIN -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Host "   ❌ ERROR: Failed to install Vector service" -ForegroundColor Red
    exit 1
}

# Start the service
Write-Host "   Starting Vector service..." -ForegroundColor Cyan
Start-Service -Name "Vector"
Start-Sleep -Seconds 2

Write-Host "   ✅ Windows Service created and started" -ForegroundColor Green
Write-Host ""

# Step 8: Verify service is running
Write-Host "🔍 Step 8/8: Verifying service status..." -ForegroundColor Yellow
$service = Get-Service -Name "Vector" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "   ✅ Vector service is running" -ForegroundColor Green
    Write-Host "   Service Status: $($service.Status)" -ForegroundColor Gray
    Write-Host "   Display Name: $($service.DisplayName)" -ForegroundColor Gray
} else {
    Write-Host "   ❌ ERROR: Vector service is not running" -ForegroundColor Red
    Write-Host "   Check Event Viewer for errors" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Register agent with O.A.S.I.S.
Write-Host "📝 Registering agent with O.A.S.I.S..." -ForegroundColor Yellow
$HOSTNAME = $env:COMPUTERNAME

$registrationBody = @{
    hostname = $HOSTNAME
    agent_type = "vector"
    os_type = "Windows"
    os_version = $OS_VERSION
    agent_version = $VECTOR_VERSION_INSTALLED
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$OASIS_GATEWAY/api/v1/agents/register" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $OASIS_API_KEY"
            "Content-Type" = "application/json"
        } `
        -Body $registrationBody `
        -UseBasicParsing `
        -SkipCertificateCheck

    if ($response.agent_id) {
        Write-Host "   ✅ Agent registered successfully" -ForegroundColor Green
        Write-Host "   Agent ID: $($response.agent_id)" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  WARNING: Unexpected registration response" -ForegroundColor Yellow
        Write-Host "   Response: $response" -ForegroundColor Gray
    }
}
catch {
    Write-Host "   ⚠️  WARNING: Agent registration may have failed" -ForegroundColor Yellow
    Write-Host "   $_" -ForegroundColor Gray
    Write-Host "   (Logs will still be sent, but agent may not appear in dashboard)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:"
Write-Host "  Vector Version: $VECTOR_VERSION_INSTALLED"
Write-Host "  Config: $VECTOR_CONFIG"
Write-Host "  Service: Windows Service 'Vector'"
Write-Host "  O.A.S.I.S. Gateway: $OASIS_GATEWAY"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "  1. Monitor service:"
Write-Host "     Get-Service Vector"
Write-Host "  2. View logs:"
Write-Host "     Get-Content $VECTOR_LOG_DIR\vector.log -Wait"
Write-Host "  3. Verify logs in O.A.S.I.S. dashboard"
Write-Host ""
Write-Host "To uninstall, run: .\scripts\cleanup-vector.ps1"
Write-Host ""

# Clean up temp directory
Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
