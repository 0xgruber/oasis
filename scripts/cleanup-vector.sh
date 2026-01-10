#!/bin/bash
# O.A.S.I.S. Vector Cleanup Script (Linux)
# Removes all Vector installations and configurations
# 
# Usage: sudo bash scripts/cleanup-vector.sh

set -e

echo "========================================"
echo "Vector Cleanup Script (Linux)"
echo "========================================"
echo ""

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
  echo "❌ ERROR: This script must be run as root (use sudo)"
  exit 1
fi

# Detect OS
OS_TYPE=$(uname -s)

if [ "$OS_TYPE" != "Linux" ]; then
  echo "❌ ERROR: This script only supports Linux"
  echo "   Detected OS: $OS_TYPE"
  echo ""
  echo "For Windows, use: scripts\\cleanup-vector.ps1"
  exit 1
fi

echo "Detected OS: Linux"
echo ""

# Step 1: Stop Vector service
echo "🛑 Step 1/7: Stopping Vector service..."

if systemctl is-active --quiet vector 2>/dev/null; then
  echo "   Stopping Vector systemd service..."
  systemctl stop vector
  systemctl disable vector
  echo "   ✅ Service stopped and disabled"
else
  echo "   ℹ️  Vector service not running"
fi
echo ""

# Step 2: Uninstall Vector
echo "🗑️  Step 2/7: Uninstalling Vector..."

# Remove binary installed by official installer
if [ -f "/usr/local/bin/vector" ]; then
  echo "   Removing /usr/local/bin/vector..."
  rm -f /usr/local/bin/vector
  echo "   ✅ Vector binary removed"
else
  echo "   ℹ️  Vector binary not found"
fi
echo ""

# Step 3: Remove configuration files
echo "🗑️  Step 3/7: Removing configuration files..."

if [ -d "/etc/vector" ]; then
  echo "   Removing /etc/vector..."
  rm -rf /etc/vector
  echo "   ✅ Configuration directory removed"
else
  echo "   ℹ️  Configuration directory not found"
fi
echo ""

# Step 4: Remove data directory
echo "🗑️  Step 4/7: Removing data directory..."

if [ -d "/var/lib/vector" ]; then
  echo "   Removing /var/lib/vector..."
  rm -rf /var/lib/vector
  echo "   ✅ Data directory removed"
else
  echo "   ℹ️  Data directory not found"
fi
echo ""

# Step 5: Remove service file
echo "🗑️  Step 5/7: Removing systemd service file..."

if [ -f "/etc/systemd/system/vector.service" ]; then
  echo "   Removing /etc/systemd/system/vector.service..."
  rm -f /etc/systemd/system/vector.service
  systemctl daemon-reload
  echo "   ✅ Service file removed"
else
  echo "   ℹ️  Service file not found"
fi
echo ""

# Step 6: Remove logs
echo "🗑️  Step 6/7: Removing logs..."

# Vector logs might be in various locations
LOG_LOCATIONS=(
  "/var/log/vector.log"
  "/var/log/vector"
)

REMOVED_LOGS=false
for log_path in "${LOG_LOCATIONS[@]}"; do
  if [ -e "$log_path" ]; then
    echo "   Removing $log_path..."
    rm -rf "$log_path"
    REMOVED_LOGS=true
  fi
done

if [ "$REMOVED_LOGS" = true ]; then
  echo "   ✅ Logs removed"
else
  echo "   ℹ️  No logs found"
fi
echo ""

# Step 7: Final verification
echo "🔍 Step 7/7: Final verification..."

# Verification
echo ""
echo "========================================"
echo "✅ Cleanup Complete!"
echo "========================================"
echo ""
echo "Verification:"

# Check if Vector binary exists
if command -v vector &> /dev/null; then
  echo "  ⚠️  Vector binary still found: $(which vector)" 
else
  echo "  ✅ Vector binary: Not found"
fi

# Check if service exists
if systemctl list-unit-files | grep -q "vector.service"; then
  echo "  ⚠️  Vector service still exists"
else
  echo "  ✅ Vector service: Not found"
fi

# Check if config exists
if [ -d "/etc/vector" ]; then
  echo "  ⚠️  Configuration directory still exists"
else
  echo "  ✅ Configuration directory: Not found"
fi

# Check if data directory exists
if [ -d "/var/lib/vector" ]; then
  echo "  ⚠️  Data directory still exists"
else
  echo "  ✅ Data directory: Not found"
fi

echo ""
echo "Vector has been successfully uninstalled from this system."
echo ""
