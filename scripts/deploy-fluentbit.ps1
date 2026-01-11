###############################################################################
# O.A.S.I.S. Fluent Bit Agent Deployment Script (Windows)
# 
# This script installs and configures Fluent Bit for log collection
# and forwards logs to the O.A.S.I.S. Internal Gateway.
#
# Prerequisites:
#   - Administrator privileges
#   - Network connectivity to O.A.S.I.S. Gateway
#   - Valid API key and CA certificate
#   - Windows Server 2016+ or Windows 10+
#
# Usage:
#   .\deploy-fluentbit.ps1
#   (Right-click, Run as Administrator)
#
###############################################################################

#Requires -RunAsAdministrator

# Script configuration
$ErrorActionPreference = "Stop"
$FLUENT_BIT_VERSION = "3.0.3"
$INSTALL_DIR = "C:\fluent-bit"
$CONFIG_DIR = "C:\fluent-bit\conf"
$LOG_DIR = "C:\ProgramData\fluent-bit\logs"
$STORAGE_DIR = "C:\ProgramData\fluent-bit\storage"
$SERVICE_NAME = "fluent-bit"
$DOWNLOAD_URL = "https://packages.fluentbit.io/windows/fluent-bit-$FLUENT_BIT_VERSION-win64.zip"

# O.A.S.I.S. Configuration (Hardcoded)
$OASIS_GATEWAY_HOST = "192.168.5.32"
$OASIS_GATEWAY_PORT = "8444"
$OASIS_API_KEY = "oasis_pk_FfCjHivG-Q-QN2lBD7Dl6-YQtoPaPnKEJsqXVLEkWwo"
$OASIS_TENANT_ID = "ffffffff-ffff-ffff-ffff-ffffffffffff"

# Embedded CA Certificate
$OASIS_CA_CERT = @'
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
'@

###############################################################################
# Helper Functions
###############################################################################

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function     Get-Configuration {
    Write-Info "=== O.A.S.I.S. Configuration ==="
    Write-Host ""
    Write-Host "  Gateway: ${OASIS_GATEWAY_HOST}:${OASIS_GATEWAY_PORT}"
    Write-Host "  Tenant:  ${OASIS_TENANT_ID}"
    Write-Host "  API Key: ${OASIS_API_KEY}"
    Write-Host ""
}

function Install-FluentBit {
    Write-Info "Installing Fluent Bit $FLUENT_BIT_VERSION..."
    
    # Check if already installed
    if (Test-Path $INSTALL_DIR) {
        Write-Warning "Fluent Bit is already installed at $INSTALL_DIR"
        $response = Read-Host "Do you want to reinstall? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Info "Skipping installation"
            return
        }
        Write-Info "Removing existing installation..."
        Stop-ServiceIfExists
        Remove-Item -Path $INSTALL_DIR -Recurse -Force
    }
    
    # Create temporary download directory
    $tempDir = Join-Path $env:TEMP "fluent-bit-install"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $zipFile = Join-Path $tempDir "fluent-bit.zip"
    
    try {
        # Download Fluent Bit
        Write-Info "Downloading Fluent Bit from $DOWNLOAD_URL..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $zipFile -UseBasicParsing
        
        # Extract archive
        Write-Info "Extracting archive..."
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        
        # Move to installation directory
        $extractedDir = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "fluent-bit-*" } | Select-Object -First 1
        if ($null -eq $extractedDir) {
            throw "Failed to find extracted Fluent Bit directory"
        }
        
        Move-Item -Path $extractedDir.FullName -Destination $INSTALL_DIR -Force
        
        Write-Success "Fluent Bit installed successfully"
    }
    catch {
        Write-Error "Installation failed: $_"
        exit 1
    }
    finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}

function Register-Agent {
    Write-Info "Registering agent with O.A.S.I.S...."
    
    $hostname = $env:COMPUTERNAME
    $osVersion = [System.Environment]::OSVersion.VersionString
    $agentVersion = & "$INSTALL_DIR\bin\fluent-bit.exe" --version 2>&1 | Select-String -Pattern "Fluent Bit v([0-9\.]+)" | ForEach-Object { $_.Matches.Groups[1].Value }
    
    $body = @{
        hostname = $hostname
        agent_type = "fluent-bit"
        os_type = "Windows"
        os_version = $osVersion
        agent_version = $agentVersion
        metadata = @{
            deployment_script = "deploy-fluentbit.ps1"
            deployment_date = (Get-Date -Format "o")
        }
    } | ConvertTo-Json
    
    try {
        $headers = @{
            "Authorization" = "Bearer $OASIS_API_KEY"
            "Content-Type" = "application/json"
        }
        
        # Import CA certificate for this session
        $certPath = Join-Path $CONFIG_DIR "oasis-ca.pem"
        
        $response = Invoke-RestMethod -Uri "https://${OASIS_GATEWAY_HOST}:${OASIS_GATEWAY_PORT}/api/v1/agents/register" `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ContentType "application/json" `
            -SkipCertificateCheck
        
        Write-Success "Agent registered successfully"
    }
    catch {
        Write-Warning "Agent registration failed: $_"
        Write-Info "Continuing with deployment..."
    }
}

function New-Configuration {
    Write-Info "Creating Fluent Bit configuration..."
    
    # Create directories
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $STORAGE_DIR -Force | Out-Null
    
    # Write embedded CA certificate
    $certPath = Join-Path $CONFIG_DIR "oasis-ca.pem"
    Set-Content -Path $certPath -Value $OASIS_CA_CERT -Encoding UTF8
    Write-Info "CA certificate written to $certPath"
    
    # Create main configuration
    $mainConfig = @"
[SERVICE]
    Flush                     5
    Daemon                    Off
    Log_Level                 info
    Log_File                  $LOG_DIR/fluent-bit.log
    Parsers_File              parsers.conf
    storage.path              $STORAGE_DIR/
    storage.sync              normal
    storage.checksum          off
    storage.max_chunks_up     128
    storage.backlog.mem_limit 50M

# ============================================
# Input: Windows Event Log - System
# ============================================
[INPUT]
    Name                      winlog
    Tag                       windows.system
    Channels                  System
    Interval_Sec              1
    Read_Existing_Events      Off
    storage.type              filesystem

# ============================================
# Input: Windows Event Log - Application
# ============================================
[INPUT]
    Name                      winlog
    Tag                       windows.application
    Channels                  Application
    Interval_Sec              1
    Read_Existing_Events      Off
    storage.type              filesystem

# ============================================
# Input: Windows Event Log - Security
# ============================================
[INPUT]
    Name                      winlog
    Tag                       windows.security
    Channels                  Security
    Interval_Sec              1
    Read_Existing_Events      Off
    storage.type              filesystem

# ============================================
# Filter: Add metadata
# ============================================
[FILTER]
    Name                      modify
    Match                     *
    Add                       tenant_id $OASIS_TENANT_ID
    Add                       hostname `${COMPUTERNAME}
    Add                       source_type windows_eventlog
    Add                       agent_type fluent-bit

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

"@
    
    Set-Content -Path (Join-Path $CONFIG_DIR "fluent-bit.conf") -Value $mainConfig -Encoding UTF8
    
    # Create parsers configuration
    $parsersConfig = @"
[PARSER]
    Name                      json
    Format                    json
    Time_Key                  time
    Time_Format               %Y-%m-%dT%H:%M:%S.%L
    Time_Keep                 On

"@
    
    Set-Content -Path (Join-Path $CONFIG_DIR "parsers.conf") -Value $parsersConfig -Encoding UTF8
    
    Write-Success "Configuration created at $CONFIG_DIR"
}

function Stop-ServiceIfExists {
    if (Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue) {
        Write-Info "Stopping existing service..."
        Stop-Service -Name $SERVICE_NAME -Force
        & sc.exe delete $SERVICE_NAME | Out-Null
        Start-Sleep -Seconds 2
    }
}

function New-WindowsService {
    Write-Info "Creating Windows service..."
    
    Stop-ServiceIfExists
    
    # Create service using nssm or sc.exe
    $binPath = Join-Path $INSTALL_DIR "bin\fluent-bit.exe"
    $configPath = Join-Path $CONFIG_DIR "fluent-bit.conf"
    
    # Use sc.exe to create service
    $scCommand = "sc.exe create $SERVICE_NAME binPath= `"$binPath -c $configPath`" start= auto DisplayName= `"Fluent Bit - O.A.S.I.S. Log Forwarder`""
    Invoke-Expression $scCommand | Out-Null
    
    # Set service description
    & sc.exe description $SERVICE_NAME "Fluent Bit log forwarder for O.A.S.I.S. SIEM platform" | Out-Null
    
    # Configure service recovery options
    & sc.exe failure $SERVICE_NAME reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
    
    Write-Success "Windows service created"
}

function Start-FluentBitService {
    Write-Info "Starting Fluent Bit service..."
    
    Start-Service -Name $SERVICE_NAME
    Start-Sleep -Seconds 3
    
    $service = Get-Service -Name $SERVICE_NAME
    if ($service.Status -eq "Running") {
        Write-Success "Fluent Bit service started successfully"
    } else {
        Write-Error "Failed to start Fluent Bit service. Status: $($service.Status)"
        Write-Info "Check logs at: $LOG_DIR\fluent-bit.log"
        exit 1
    }
}

function Show-Summary {
    Write-Host ""
    Write-Success "=== Deployment Complete ==="
    Write-Host ""
    Write-Host "Configuration files:"
    Write-Host "  - Main config:   $CONFIG_DIR\fluent-bit.conf"
    Write-Host "  - Parsers:       $CONFIG_DIR\parsers.conf"
    Write-Host "  - CA cert:       $CONFIG_DIR\oasis-ca.pem"
    Write-Host ""
    Write-Host "Log files:"
    Write-Host "  - Fluent Bit:    $LOG_DIR\fluent-bit.log"
    Write-Host "  - Windows Event: Event Viewer > Applications and Services Logs"
    Write-Host ""
    Write-Host "Service commands:"
    Write-Host "  - Status:        Get-Service fluent-bit"
    Write-Host "  - Start:         Start-Service fluent-bit"
    Write-Host "  - Stop:          Stop-Service fluent-bit"
    Write-Host "  - Restart:       Restart-Service fluent-bit"
    Write-Host "  - Logs:          Get-Content '$LOG_DIR\fluent-bit.log' -Wait"
    Write-Host ""
    Write-Info "Logs are now being forwarded to O.A.S.I.S."
    Write-Host ""
}

###############################################################################
# Main Execution
###############################################################################

function Main {
    Write-Host ""
    Write-Info "=== O.A.S.I.S. Fluent Bit Deployment (Windows) ==="
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator"
        exit 1
    }
    
    Show-Configuration
    Install-FluentBit
    Register-Agent
    New-Configuration
    New-WindowsService
    Start-FluentBitService
    Show-Summary
}

# Run main function
Main
