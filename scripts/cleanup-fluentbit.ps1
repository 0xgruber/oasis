###############################################################################
# O.A.S.I.S. Fluent Bit Agent Cleanup Script (Windows)
# 
# This script completely removes Fluent Bit and all related configurations
# from the system.
#
# Prerequisites:
#   - Administrator privileges
#
# Usage:
#   .\cleanup-fluentbit.ps1
#   (Right-click, Run as Administrator)
#
###############################################################################

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$SERVICE_NAME = "OASIS-Agent"
$INSTALL_DIR = "C:\Program Files\Oasis"
$CONFIG_ROOT = "C:\ProgramData\Oasis"
$CONFIG_DIR = $CONFIG_ROOT

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

function Stop-FluentBitService {
    Write-Info "Stopping Fluent Bit service..."
    
    # Check for all possible service names (current and legacy)
    $serviceNames = @($SERVICE_NAME, "OASISAgent", "fluent-bit")
    $serviceRemoved = $false
    
    foreach ($svcName in $serviceNames) {
        $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($null -ne $service) {
            if ($service.Status -eq "Running") {
                Stop-Service -Name $svcName -Force
                Write-Success "Service stopped: $svcName"
            } else {
                Write-Info "Service is not running: $svcName"
            }
            
            # Delete service
            & sc.exe delete $svcName | Out-Null
            Write-Success "Service removed: $svcName"
            $serviceRemoved = $true
        }
    }
    
    if (-not $serviceRemoved) {
        Write-Info "Service not found"
    }
}

function Remove-Installation {
    Write-Info "Removing Fluent Bit installation..."
    
    if (Test-Path $INSTALL_DIR) {
        Remove-Item -Path $INSTALL_DIR -Recurse -Force
        Write-Success "Installation removed: $INSTALL_DIR"
    } else {
        Write-Info "Installation directory not found"
    }
}

function Remove-DataFiles {
    Write-Info "Removing configuration and data files..."
    
    if (Test-Path $CONFIG_ROOT) {
        Remove-Item -Path $CONFIG_ROOT -Recurse -Force
        Write-Success "Configuration and data removed: $CONFIG_ROOT"
    } else {
        Write-Info "Configuration directory not found"
    }
}

function Show-Summary {
    Write-Host ""
    Write-Success "=== Cleanup Complete ==="
    Write-Host ""
    Write-Info "Fluent Bit has been completely removed from this system."
    Write-Host ""
}

function Remove-Dependencies {
    Write-Host ""
    Write-Info "=== Dependency Removal ==="
    Write-Host ""
    Write-Info "Checking for additional Fluent Bit components..."
    Write-Host ""

    # Check for Fluent Bit installation in other locations (possible manual installs)
    $fluentbitPaths = @(
        "C:\Program Files\fluent-bit",
        "C:\Program Files (x86)\fluent-bit",
        "${env:ProgramData}\fluent-bit",
        "${env:LOCALAPPDATA}\fluent-bit"
    )

    $foundPaths = @()
    foreach ($path in $fluentbitPaths) {
        if (Test-Path $path) {
            $foundPaths += $path
            Write-Info "Found Fluent Bit installation: $path"
        }
    }

    if ($foundPaths.Count -gt 0) {
        Write-Host ""
        $response = Read-Host "Would you like to remove these additional Fluent Bit installations? [(y)es/(N)o]"
        if ($response -eq "y" -or $response -eq "Y") {
            foreach ($path in $foundPaths) {
                Write-Info "Removing: $path"
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path $path)) {
                    Write-Success "Removed: $path"
                }
            }
        } else {
            Write-Info "Skipping additional Fluent Bit installations"
        }
    } else {
        Write-Info "No additional Fluent Bit installations found"
    }

    Write-Host ""
    Write-Info "Note: This script does not remove system-level dependencies as Windows components (curl, etc.) are provided by the operating system."
    Write-Host ""
}

function Main {
    Write-Host ""
    Write-Info "=== O.A.S.I.S. Fluent Bit Cleanup (Windows) ==="
    Write-Host ""

    $response = Read-Host "This will completely remove Fluent Bit. Continue? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Info "Cleanup cancelled"
        exit 0
    }

    Write-Host ""
    $removeDeps = Read-Host "Would you like to check for and remove additional Fluent Bit installations? [Y/n]"
    Write-Host ""

    Stop-FluentBitService
    Remove-Installation
    Remove-DataFiles

    if ($removeDeps -eq "" -or $removeDeps -eq "y" -or $removeDeps -eq "Y") {
        Remove-Dependencies
    }

    Show-Summary
}

# Run main function
Main
