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
$SERVICE_NAME = "OASISAgent"
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
    
    $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
    if ($null -ne $service) {
        if ($service.Status -eq "Running") {
            Stop-Service -Name $SERVICE_NAME -Force
            Write-Success "Service stopped"
        } else {
            Write-Info "Service is not running"
        }
        
        # Delete service
        & sc.exe delete $SERVICE_NAME | Out-Null
        Write-Success "Service removed"
    } else {
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

function Main {
    Write-Host ""
    Write-Info "=== O.A.S.I.S. Fluent Bit Cleanup (Windows) ==="
    Write-Host ""
    
    $response = Read-Host "This will completely remove Fluent Bit. Continue? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Info "Cleanup cancelled"
        exit 0
    }
    
    Stop-FluentBitService
    Remove-Installation
    Remove-DataFiles
    Show-Summary
}

# Run main function
Main
