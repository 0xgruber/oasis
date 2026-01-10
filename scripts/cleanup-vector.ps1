# O.A.S.I.S. Vector Cleanup Script (Windows)
# Removes all Vector installations and configurations
# 
# Usage: Run PowerShell as Administrator, then:
#        .\scripts\cleanup-vector.ps1

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Vector Cleanup Script (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set paths
$VECTOR_INSTALL_DIR = "$env:ProgramFiles\Vector"
$VECTOR_CONFIG_DIR = "$env:ProgramData\Vector\config"
$VECTOR_DATA_DIR = "$env:ProgramData\Vector\data"
$VECTOR_LOG_DIR = "$env:ProgramData\Vector\logs"
$VECTOR_ROOT_DIR = "$env:ProgramData\Vector"

# Step 1: Stop and remove Windows Service
Write-Host "🛑 Step 1/6: Stopping Vector service..." -ForegroundColor Yellow

$service = Get-Service -Name "Vector" -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -eq "Running") {
        Write-Host "   Stopping Vector service..." -ForegroundColor Gray
        Stop-Service -Name "Vector" -Force
        Start-Sleep -Seconds 2
    }
    
    Write-Host "   Removing Vector service..." -ForegroundColor Gray
    $vectorBin = "$VECTOR_INSTALL_DIR\bin\vector.exe"
    
    if (Test-Path $vectorBin) {
        # Use Vector's built-in service uninstall command
        $process = Start-Process -FilePath $vectorBin -ArgumentList "service","uninstall" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "   ✅ Vector service removed" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Warning: Service removal may have failed" -ForegroundColor Yellow
        }
    } else {
        # Fallback: use sc.exe to delete service
        sc.exe delete Vector | Out-Null
        Write-Host "   ✅ Vector service removed (fallback method)" -ForegroundColor Green
    }
} else {
    Write-Host "   ℹ️  Vector service not found" -ForegroundColor Gray
}
Write-Host ""

# Step 2: Uninstall Vector MSI
Write-Host "🗑️  Step 2/6: Uninstalling Vector..." -ForegroundColor Yellow

# Get installed Vector product
$vectorProduct = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Vector*" }

if ($vectorProduct) {
    Write-Host "   Found Vector installation: $($vectorProduct.Name)" -ForegroundColor Gray
    Write-Host "   Uninstalling..." -ForegroundColor Gray
    
    try {
        $vectorProduct.Uninstall() | Out-Null
        Write-Host "   ✅ Vector uninstalled via MSI" -ForegroundColor Green
    }
    catch {
        Write-Host "   ⚠️  Warning: MSI uninstall failed: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ℹ️  Vector MSI package not found" -ForegroundColor Gray
}

# Manual cleanup of install directory
if (Test-Path $VECTOR_INSTALL_DIR) {
    Write-Host "   Removing installation directory..." -ForegroundColor Gray
    Remove-Item -Path $VECTOR_INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Installation directory removed" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Installation directory not found" -ForegroundColor Gray
}
Write-Host ""

# Step 3: Remove configuration files
Write-Host "🗑️  Step 3/6: Removing configuration files..." -ForegroundColor Yellow

if (Test-Path $VECTOR_CONFIG_DIR) {
    Write-Host "   Removing $VECTOR_CONFIG_DIR..." -ForegroundColor Gray
    Remove-Item -Path $VECTOR_CONFIG_DIR -Recurse -Force
    Write-Host "   ✅ Configuration directory removed" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Configuration directory not found" -ForegroundColor Gray
}
Write-Host ""

# Step 4: Remove data directory
Write-Host "🗑️  Step 4/6: Removing data directory..." -ForegroundColor Yellow

if (Test-Path $VECTOR_DATA_DIR) {
    Write-Host "   Removing $VECTOR_DATA_DIR..." -ForegroundColor Gray
    Remove-Item -Path $VECTOR_DATA_DIR -Recurse -Force
    Write-Host "   ✅ Data directory removed" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Data directory not found" -ForegroundColor Gray
}
Write-Host ""

# Step 5: Remove logs
Write-Host "🗑️  Step 5/6: Removing logs..." -ForegroundColor Yellow

if (Test-Path $VECTOR_LOG_DIR) {
    Write-Host "   Removing $VECTOR_LOG_DIR..." -ForegroundColor Gray
    Remove-Item -Path $VECTOR_LOG_DIR -Recurse -Force
    Write-Host "   ✅ Logs removed" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Logs not found" -ForegroundColor Gray
}

# Remove root Vector directory if empty
if (Test-Path $VECTOR_ROOT_DIR) {
    $items = Get-ChildItem -Path $VECTOR_ROOT_DIR -ErrorAction SilentlyContinue
    if ($items.Count -eq 0) {
        Remove-Item -Path $VECTOR_ROOT_DIR -Force
        Write-Host "   ✅ Root Vector directory removed" -ForegroundColor Green
    }
}
Write-Host ""

# Step 6: Final verification
Write-Host "🔍 Step 6/6: Final verification..." -ForegroundColor Yellow
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Verification:"

# Check if Vector service exists
$service = Get-Service -Name "Vector" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  ⚠️  Vector service still exists: $($service.Status)" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Vector service: Not found" -ForegroundColor Green
}

# Check if Vector binary exists
if (Test-Path "$VECTOR_INSTALL_DIR\bin\vector.exe") {
    Write-Host "  ⚠️  Vector binary still exists" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Vector binary: Not found" -ForegroundColor Green
}

# Check if config directory exists
if (Test-Path $VECTOR_CONFIG_DIR) {
    Write-Host "  ⚠️  Configuration directory still exists" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Configuration directory: Not found" -ForegroundColor Green
}

# Check if data directory exists
if (Test-Path $VECTOR_DATA_DIR) {
    Write-Host "  ⚠️  Data directory still exists" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Data directory: Not found" -ForegroundColor Green
}

Write-Host ""
Write-Host "Vector has been successfully uninstalled from this system." -ForegroundColor Cyan
Write-Host ""
