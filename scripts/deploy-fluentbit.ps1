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
$INSTALL_DIR = "C:\Program Files\Oasis"
$CONFIG_ROOT = "C:\ProgramData\Oasis"
$CONFIG_DIR = $CONFIG_ROOT
$LOG_DIR = "$CONFIG_ROOT\logs"
$STORAGE_DIR = "$CONFIG_ROOT\storage"
$TENANT_CONFIG = "$CONFIG_ROOT\tenant.conf"
$SERVICE_NAME = "OASIS-Agent"
$SERVICE_DISPLAY_NAME = "OASIS Agent"
$DOWNLOAD_URL = "https://packages.fluentbit.io/windows/fluent-bit-$FLUENT_BIT_VERSION-win64.exe"

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

function Initialize-Directories {
    Write-Info "Initializing required directories..."
    
    # Create base directories if they don't exist
    if (-not (Test-Path $CONFIG_ROOT)) {
        Write-Info "Creating configuration root directory: $CONFIG_ROOT"
        New-Item -ItemType Directory -Path $CONFIG_ROOT -Force | Out-Null
    }
    
    if (-not (Test-Path $INSTALL_DIR)) {
        Write-Info "Creating installation directory: $INSTALL_DIR"
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }
    
    Write-Success "Required directories initialized"
}

function Load-TenantConfig {
    Write-Info "Loading tenant configuration from $TENANT_CONFIG..."
    
    # Check if tenant.conf exists in config directory
    if (-not (Test-Path $TENANT_CONFIG)) {
        # Try to copy from current directory
        $localTenantConfig = Join-Path (Get-Location) "tenant.conf"
        if (Test-Path $localTenantConfig) {
            Write-Info "Found tenant.conf in current directory, copying to $TENANT_CONFIG..."
            Copy-Item -Path $localTenantConfig -Destination $TENANT_CONFIG -Force
            Write-Success "Tenant configuration copied successfully"
        } else {
            Write-Error "Tenant configuration file not found: $TENANT_CONFIG"
            Write-Host ""
            Write-Host "Please place tenant.conf in the current directory or create $TENANT_CONFIG with the following content:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "OASIS_GATEWAY_HOST=your.gateway.host"
            Write-Host "OASIS_GATEWAY_PORT=8444"
            Write-Host "OASIS_API_KEY=your_api_key"
            Write-Host "OASIS_TENANT_ID=your_tenant_uuid"
            Write-Host ""
            Write-Host "You can generate this file from the O.A.S.I.S. Dashboard." -ForegroundColor Yellow
            exit 1
        }
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
    $binPath = Join-Path $INSTALL_DIR "bin\fluent-bit.exe"
    if (Test-Path $binPath) {
        Write-Warning "Fluent Bit is already installed at $INSTALL_DIR"
        $response = Read-Host "Do you want to reinstall? (y/n)"
        if ($response -ne 'y') {
            Write-Info "Skipping installation"
            return
        }
        Write-Info "Removing existing installation..."
        
        # Stop any services before uninstalling
        $servicesToStop = @("OASIS-Agent", "OASISAgent", "fluent-bit", "fluentbit")
        foreach ($svcName in $servicesToStop) {
            $existingService = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($existingService) {
                Write-Info "Stopping service: $svcName..."
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                & sc.exe delete $svcName | Out-Null
            }
        }
        
        Start-Sleep -Seconds 2
        
        # Try to uninstall using the uninstaller if it exists
        $uninstaller = Join-Path $INSTALL_DIR "Uninstall.exe"
        if (Test-Path $uninstaller) {
            Write-Info "Running uninstaller..."
            Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait -NoNewWindow
            Start-Sleep -Seconds 3
        }
        
        # Remove directory if still exists
        if (Test-Path $INSTALL_DIR) {
            Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Create temporary download directory
    $tempDir = Join-Path $env:TEMP "fluent-bit-install"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $installerFile = Join-Path $tempDir "fluent-bit-installer.exe"
    
    try {
        # Download Fluent Bit installer
        Write-Info "Downloading Fluent Bit installer from $DOWNLOAD_URL..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Download with certificate validation bypass
        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
            $certCallback = @"
                using System;
                using System.Net;
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public class ServerCertificateValidationCallback {
                    public static void Ignore() {
                        if(ServicePointManager.ServerCertificateValidationCallback == null) {
                            ServicePointManager.ServerCertificateValidationCallback += 
                                delegate (
                                    Object obj, 
                                    X509Certificate certificate, 
                                    X509Chain chain, 
                                    SslPolicyErrors errors
                                ) {
                                    return true;
                                };
                        }
                    }
                }
"@
            Add-Type $certCallback
        }
        [ServerCertificateValidationCallback]::Ignore()
        
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $installerFile -UseBasicParsing
        
        # Verify download
        if (-not (Test-Path $installerFile)) {
            throw "Failed to download installer"
        }
        
        $fileSize = (Get-Item $installerFile).Length
        Write-Info "Downloaded installer: $([math]::Round($fileSize/1MB, 2)) MB"
        
        # Run installer silently
        Write-Info "Running installer (silent mode)..."
        Write-Info "Installing to: $INSTALL_DIR"
        
        # NSIS installer syntax: /S for silent, /D= for install directory (must be last parameter, no quotes)
        $installArgs = "/S /D=$INSTALL_DIR"
        
        Write-Info "Installer command: $installerFile $installArgs"
        
        $process = Start-Process -FilePath $installerFile -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            throw "Installer failed with exit code: $($process.ExitCode)"
        }
        
        # Wait for installation to complete
        Write-Info "Waiting for installation to complete..."
        Start-Sleep -Seconds 5
        
        # Verify installation
        if (-not (Test-Path $binPath)) {
            throw "Installation completed but binary not found at: $binPath"
        }
        
        # Get installed version
        $version = & $binPath --version 2>&1 | Select-Object -First 1
        Write-Success "Fluent Bit installed successfully: $version"
        
    }
    catch {
        Write-Error "Installation failed: $_"
        exit 1
    }
    finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# === ENHANCED SYSTEM INFORMATION COLLECTION ===

function Get-WindowsVersion {
    # Get Windows version directly from registry
    $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    return "$($reg.ProductName) $($reg.DisplayVersion) (Build: $($reg.CurrentBuild).$($reg.UBR))"
}

function Get-SystemArchitecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "AMD64 (64-bit)" }
        "ARM64" { return "ARM64 (64-bit ARM)" }
        "x86" { return "x86 (32-bit)" }
        default { return $arch }
    }
}

function Get-AllMacAddresses {
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -or $_.Status -eq "Disconnected" }
        $macList = @()
        foreach ($adapter in $adapters) {
            $mac = $adapter.MacAddress -replace "-", ":"
            $macList += "$($adapter.Name): $mac"
        }
        return ($macList -join ";")
    }
    catch {
        return "Error collecting MAC addresses: $($_.Exception.Message)"
    }
}

function Get-NetworkInterfaces {
    try {
        $interfaces = Get-NetAdapter | Select-Object -ExpandProperty Name
        return ($interfaces -join ",")
    }
    catch {
        return "Error collecting interfaces: $($_.Exception.Message)"
    }
}

function Register-Agent {
    Write-Info "Registering agent with O.A.S.I.S...."

    $hostname = $env:COMPUTERNAME
    $osVersion = Get-WindowsVersion
    $agentVersion = & "$INSTALL_DIR\bin\fluent-bit.exe" --version 2>&1 | Select-String -Pattern "Fluent Bit v([0-9\.]+)" | ForEach-Object { $_.Matches.Groups[1].Value }

    $arch = Get-SystemArchitecture
    $macAddresses = Get-AllMacAddresses
    $interfaces = Get-NetworkInterfaces

    $body = @{
        hostname = $hostname
        agent_type = "fluent-bit"
        os_type = "Windows"
        os_version = $osVersion
        agent_version = $agentVersion
        metadata = @{
            deployment_script = "deploy-fluentbit.ps1"
            deployment_date = (Get-Date -Format "o")
            architecture = $arch
            mac_addresses = $macAddresses
            network_interfaces = $interfaces
        }
    } | ConvertTo-Json

    Write-Debug "OS Version: $osVersion"
    Write-Debug "Architecture: $arch"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $OASIS_API_KEY"
            "Content-Type" = "application/json"
        }
        
        # Import CA certificate for this session
        $certPath = Join-Path $CONFIG_DIR "oasis-ca.pem"
        
        # Skip certificate validation (compatible with older PowerShell versions)
        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
            $certCallback = @"
                using System;
                using System.Net;
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public class ServerCertificateValidationCallback {
                    public static void Ignore() {
                        ServicePointManager.ServerCertificateValidationCallback += 
                            delegate(Object obj, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
                                return true;
                            };
                    }
                }
"@
            Add-Type $certCallback
        }
        [ServerCertificateValidationCallback]::Ignore()
        
        $response = Invoke-RestMethod -Uri "https://${OASIS_GATEWAY_HOST}:${OASIS_GATEWAY_PORT}/api/v1/agents/register" `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ContentType "application/json"
        
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
    # Convert paths to forward slashes for Fluent Bit
    $logDirUnix = $LOG_DIR -replace '\\', '/'
    $storageDirUnix = $STORAGE_DIR -replace '\\', '/'
    $configDirUnix = $CONFIG_DIR -replace '\\', '/'
    
    $mainConfig = @"
[SERVICE]
    Flush                     5
    Daemon                    Off
    Log_Level                 info
    Log_File                  $logDirUnix/fluent-bit.log
    Parsers_File              $configDirUnix/parsers.conf
    storage.path              $storageDirUnix/
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
    Add                       hostname `${env:COMPUTERNAME}
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
    tls.ca_file               $configDirUnix/oasis-ca.pem
    Retry_Limit               5
    storage.total_limit_size  500M
    net.keepalive             On
    net.keepalive_idle_timeout 30

"@
    
    
    # Write config without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $configFilePath = Join-Path $CONFIG_DIR "fluent-bit.conf"
    [System.IO.File]::WriteAllText($configFilePath, $mainConfig, $utf8NoBom)
    
    # Debug: Show first few lines of generated config
    Write-Info "Generated configuration (first 15 lines):"
    Get-Content $configFilePath | Select-Object -First 15 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
    
    # Verify file was written correctly
    $fileInfo = Get-Item $configFilePath
    Write-Info "Config file size: $($fileInfo.Length) bytes"
    
    # Check for BOM
    $bytes = [System.IO.File]::ReadAllBytes($configFilePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Warning "Config file has UTF-8 BOM (this may cause issues)"
    } else {
        Write-Info "Config file encoding: UTF-8 without BOM (correct)"
    }
    
    # Create parsers configuration
    $parsersConfig = @"
[PARSER]
    Name                      json
    Format                    json
    Time_Key                  time
    Time_Format               %Y-%m-%dT%H:%M:%S.%L
    Time_Keep                 On

"@
    
    # Write parsers config without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $CONFIG_DIR "parsers.conf"), $parsersConfig, $utf8NoBom)
    
    Write-Success "Configuration created at $CONFIG_DIR"
    Write-Info "  - fluent-bit.conf"
    Write-Info "  - parsers.conf"
    Write-Info "  - oasis-ca.pem"
}

function New-WindowsService {
    Write-Info "Configuring Windows service..."
    
    $binPath = Join-Path $INSTALL_DIR "bin\fluent-bit.exe"
    $configPath = Join-Path $CONFIG_DIR "fluent-bit.conf"
    
    Write-Info "Binary: $binPath"
    Write-Info "Config: $configPath"
    
    # Verify files exist
    if (-not (Test-Path $binPath)) {
        Write-Error "Binary not found: $binPath"
        exit 1
    }
    
    if (-not (Test-Path $configPath)) {
        Write-Error "Config not found: $configPath"
        exit 1
    }
    
    # Validate configuration by doing a dry run
    Write-Info "Validating configuration..."
    try {
        $dryRunOutput = & $binPath -c $configPath --dry-run 2>&1
        $dryRunExitCode = $LASTEXITCODE
        
        if ($dryRunExitCode -ne 0) {
            Write-Warning "Configuration validation failed (exit code: $dryRunExitCode)"
            Write-Warning "Dry-run output:"
            $dryRunOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
            Write-Warning "Continuing with service creation anyway..."
        } else {
            Write-Success "Configuration validation passed"
        }
    }
    catch {
        Write-Warning "Could not validate configuration: $_"
        Write-Info "Continuing with service creation..."
    }
    
    # Check if installer created a default service
    $installerServiceNames = @("fluent-bit", "fluentbit")
    $installerCreatedService = $null
    
    foreach ($svcName in $installerServiceNames) {
        $existingService = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Info "Found installer-created service: $svcName"
            $installerCreatedService = $svcName
            break
        }
    }
    
    # Stop and remove any existing services (including old OASIS ones)
    $servicesToRemove = @($SERVICE_NAME, "OASISAgent")
    if ($installerCreatedService) {
        $servicesToRemove += $installerCreatedService
    }
    
    foreach ($svcName in $servicesToRemove) {
        $existingService = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Info "Stopping and removing existing service: $svcName..."
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            & sc.exe delete $svcName | Out-Null
            Start-Sleep -Seconds 2
        }
    }
    
    try {
        # Create new service with our configuration
        # Use sc.exe to create the service (matches official Fluent Bit documentation)
        # Format: binPath= "path\to\fluent-bit.exe" -c "path\to\config.conf"
        # Note: key is case-insensitive, but docs use binPath= (with capital P).
        $binaryPathName = "`"$binPath`" -c `"$configPath`""
        
        Write-Info "Creating service '$SERVICE_NAME' with display name '$SERVICE_DISPLAY_NAME'..."
        Write-Info "Service command line: $binaryPathName"
        
        # Create service with sc.exe - note the syntax: binpath= (with equals and space after)
        # sc.exe parsing is finicky; build a single command string so quoting survives
        $scCreateArgs = "create `"$SERVICE_NAME`" binPath= `"$binaryPathName`" start= auto DisplayName= `"$SERVICE_DISPLAY_NAME`""
        Write-Info "sc.exe args: $scCreateArgs"
        $scResult = & sc.exe $scCreateArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "sc.exe failed with exit code $LASTEXITCODE"
            Write-Error "Output: $scResult"
            exit 1
        }
        
        Write-Success "Windows service created: $SERVICE_NAME"
        
        # Set description separately as sc.exe create doesn't have a description parameter
        sc.exe description $SERVICE_NAME "Fluent Bit log forwarder for O.A.S.I.S. SIEM platform" | Out-Null
        
        # Configure service recovery options using sc.exe
        sc.exe failure $SERVICE_NAME reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
        
        # Verify the service was created correctly
        Write-Info "Verifying service configuration..."
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='$SERVICE_NAME'"
        if ($service) {
            Write-Info "  Service PathName: $($service.PathName)"
            Write-Info "  Service State: $($service.State)"
            Write-Info "  Service Start Mode: $($service.StartMode)"
        } else {
            Write-Warning "Could not retrieve service information for verification"
        }
    }
    catch {
        Write-Error "Failed to create Windows service: $_"
        exit 1
    }
}

function Start-FluentBitService {
    Write-Info "Starting Fluent Bit service..."
    
    try {
        Start-Service -Name $SERVICE_NAME -ErrorAction Stop
        Start-Sleep -Seconds 5
        
        $service = Get-Service -Name $SERVICE_NAME
        if ($service.Status -eq "Running") {
            Write-Success "Fluent Bit service started successfully"
            return
        } else {
            Write-Warning "Service status: $($service.Status)"
            # Fall through to error diagnostics below
        }
    }
    catch {
        Write-Error "Failed to start service: $_"
    }
    
    # Common error diagnostics (runs if service didn't start or threw exception)
    Write-Info "Attempting to diagnose service startup failure..."
    
    # Check Windows Application event log for recent errors
    Write-Info "Checking Windows Event Log..."
    $recentErrors = Get-EventLog -LogName Application -Source "Service Control Manager" -Newest 10 -ErrorAction SilentlyContinue | 
        Where-Object { $_.Message -like "*$SERVICE_NAME*" -or $_.Message -like "*fluent-bit*" -or $_.TimeGenerated -gt (Get-Date).AddMinutes(-5) }
    
    if ($recentErrors) {
        Write-Warning "Recent service-related events:"
        $recentErrors | ForEach-Object { 
            Write-Host "  [$($_.EntryType)] $($_.Message)" -ForegroundColor $(if ($_.EntryType -eq "Error") { "Red" } else { "Yellow" })
        }
    } else {
        Write-Info "No recent errors found in Event Log"
    }
    
    # Check if Fluent Bit log file exists and show recent content
    $fluentBitLogPath = Join-Path $LOG_DIR "fluent-bit.log"
    if (Test-Path $fluentBitLogPath) {
        Write-Info "`nFluent Bit log file contents (last 20 lines):"
        Get-Content $fluentBitLogPath -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    } else {
        Write-Info "Fluent Bit log file not created yet: $fluentBitLogPath"
    }
    
    # Try to manually test fluent-bit
    Write-Info "`nTesting fluent-bit binary manually..."
    $binPath = Join-Path $INSTALL_DIR "bin\fluent-bit.exe"
    $configPath = Join-Path $CONFIG_DIR "fluent-bit.conf"
    
    if (Test-Path $binPath) {
        Write-Info "Binary version:"
        & $binPath --version
        
        Write-Info "`nTesting configuration file..."
        if (Test-Path $configPath) {
            Write-Info "Running fluent-bit with config (will run for 5 seconds)..."
            $job = Start-Job -ScriptBlock { 
                param($bin, $conf)
                & $bin -c $conf 2>&1
            } -ArgumentList $binPath, $configPath
            
            Start-Sleep -Seconds 5
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            $output = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            Write-Host "`nFluent Bit manual execution output:" -ForegroundColor Yellow
            if ($output) {
                $output | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host "  (no output captured)" -ForegroundColor Gray
            }
        } else {
            Write-Error "Config not found at: $configPath"
        }
    } else {
        Write-Error "Binary not found at: $binPath"
    }
    
    Write-Host ""
    Write-Info "Additional debugging steps:"
    Write-Info "1. Check service configuration: sc.exe qc $SERVICE_NAME"
    Write-Info "2. Check service status: sc.exe query $SERVICE_NAME"
    Write-Info "3. Try manual start: & '$binPath' -c '$configPath'"
    Write-Info "4. Check file permissions on: $CONFIG_DIR"
    Write-Info "5. Check logs at: $LOG_DIR\fluent-bit.log"
    
    exit 1
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
    Write-Host "  - Status:        Get-Service '$SERVICE_NAME'"
    Write-Host "  - Start:         Start-Service '$SERVICE_NAME'"
    Write-Host "  - Stop:          Stop-Service '$SERVICE_NAME'"
    Write-Host "  - Restart:       Restart-Service '$SERVICE_NAME'"
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
    
    Initialize-Directories
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
