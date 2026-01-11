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
$TENANT_CONFIG = "C:\oasis\tenant.conf"

# Tenant Configuration (loaded from tenant.conf)
$OASIS_GATEWAY_HOST = ""
$OASIS_GATEWAY_PORT = ""
$OASIS_API_KEY = ""
$OASIS_TENANT_ID = ""
$OASIS_CA_CERT = ""

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

function Load-TenantConfig {
    Write-Info "Loading tenant configuration from $TENANT_CONFIG..."
    
    if (-not (Test-Path $TENANT_CONFIG)) {
        Write-Error "Tenant configuration file not found: $TENANT_CONFIG"
        Write-Host ""
        Write-Host "Please create $TENANT_CONFIG with the following content:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "OASIS_GATEWAY_HOST=your.gateway.host"
        Write-Host "OASIS_GATEWAY_PORT=8444"
        Write-Host "OASIS_API_KEY=your_api_key"
        Write-Host "OASIS_TENANT_ID=your_tenant_uuid"
        Write-Host ""
        Write-Host "You can generate this file from the O.A.S.I.S. Dashboard." -ForegroundColor Yellow
        exit 1
    }
    
    # Load configuration file
    Get-Content $TENANT_CONFIG | ForEach-Object {
        $line = $_.Trim()
        # Skip comments and empty lines
        if ($line -and -not $line.StartsWith("#")) {
            if ($line -match "^([^=]+)=(.*)$") {
                $key = $matches[1]
                $value = $matches[2]
                Set-Variable -Name $key -Value $value -Scope Script
            }
        }
    }
    
    # Validate required variables
    if ([string]::IsNullOrWhiteSpace($script:OASIS_GATEWAY_HOST)) {
        Write-Error "OASIS_GATEWAY_HOST not set in $TENANT_CONFIG"
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($script:OASIS_API_KEY)) {
        Write-Error "OASIS_API_KEY not set in $TENANT_CONFIG"
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($script:OASIS_TENANT_ID)) {
        Write-Error "OASIS_TENANT_ID not set in $TENANT_CONFIG"
        exit 1
    }
    
    # Set default port if not specified
    if ([string]::IsNullOrWhiteSpace($script:OASIS_GATEWAY_PORT)) {
        $script:OASIS_GATEWAY_PORT = "8444"
    }
    
    # Extract CA certificate from config file
    $content = Get-Content $TENANT_CONFIG -Raw
    if ($content -match '(?s)#--- BEGIN OASIS CA CERTIFICATE ---\s*(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)\s*#--- END OASIS CA CERTIFICATE ---') {
        $script:OASIS_CA_CERT = $matches[1]
    } else {
        Write-Error "CA certificate not found in $TENANT_CONFIG"
        Write-Host "Please ensure the certificate is embedded between:" -ForegroundColor Yellow
        Write-Host "  #--- BEGIN OASIS CA CERTIFICATE ---"
        Write-Host "  #--- END OASIS CA CERTIFICATE ---"
        exit 1
    }
    
    Write-Success "Tenant configuration loaded successfully"
    Write-Info "  Gateway: ${script:OASIS_GATEWAY_HOST}:${script:OASIS_GATEWAY_PORT}"
    Write-Info "  Tenant:  ${script:OASIS_TENANT_ID}"
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
    
    Load-TenantConfig
    Install-FluentBit
    Register-Agent
    New-Configuration
    New-WindowsService
    Start-FluentBitService
    Show-Summary
}

# Run main function
Main
