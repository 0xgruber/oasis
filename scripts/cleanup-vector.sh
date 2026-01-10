#!/bin/bash
set -e

###############################################################################
# Vector Cleanup Script
# Removes all Vector installations and configurations
###############################################################################

echo "========================================"
echo "Vector Cleanup Script"
echo "========================================"
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=macOS;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${OS_TYPE}"
echo ""

if [[ "$OS_TYPE" == "UNKNOWN"* ]]; then
    echo "❌ Unsupported operating system: ${OS}"
    exit 1
fi

# Function to stop and remove services
cleanup_services() {
    echo "Stopping Vector services..."
    
    if [[ "$OS_TYPE" == "macOS" ]]; then
        # Stop and unload LaunchDaemon/LaunchAgent
        if launchctl list | grep -q "vector"; then
            echo "  - Stopping Vector via launchctl..."
            sudo launchctl stop io.vector.agent 2>/dev/null || true
            launchctl stop io.vector.agent 2>/dev/null || true
            sudo launchctl unload /Library/LaunchDaemons/io.vector.agent.plist 2>/dev/null || true
            launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.vector.plist 2>/dev/null || true
        fi
        
        # Stop Homebrew service if it exists
        if command -v brew &> /dev/null; then
            brew services stop vector 2>/dev/null || true
            sudo brew services stop vector 2>/dev/null || true
        fi
        
        echo "  ✓ Services stopped"
        
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Stop systemd service
        if systemctl is-active --quiet vector 2>/dev/null; then
            echo "  - Stopping Vector systemd service..."
            sudo systemctl stop vector
            sudo systemctl disable vector
            echo "  ✓ Service stopped and disabled"
        else
            echo "  - Vector service not running"
        fi
    fi
}

# Function to remove LaunchDaemon/systemd units
remove_service_units() {
    echo ""
    echo "Removing service units..."
    
    if [[ "$OS_TYPE" == "macOS" ]]; then
        # Remove LaunchDaemon
        if [[ -f "/Library/LaunchDaemons/io.vector.agent.plist" ]]; then
            echo "  - Removing /Library/LaunchDaemons/io.vector.agent.plist"
            sudo rm -f /Library/LaunchDaemons/io.vector.agent.plist
        fi
        
        # Remove LaunchAgent (Homebrew default)
        if [[ -f "$HOME/Library/LaunchAgents/homebrew.mxcl.vector.plist" ]]; then
            echo "  - Removing ~/Library/LaunchAgents/homebrew.mxcl.vector.plist"
            rm -f "$HOME/Library/LaunchAgents/homebrew.mxcl.vector.plist"
        fi
        
        echo "  ✓ Service units removed"
        
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Remove systemd unit
        if [[ -f "/etc/systemd/system/vector.service" ]]; then
            echo "  - Removing /etc/systemd/system/vector.service"
            sudo rm -f /etc/systemd/system/vector.service
            sudo systemctl daemon-reload
            echo "  ✓ Service unit removed"
        else
            echo "  - No systemd unit found"
        fi
    fi
}

# Function to uninstall Vector
uninstall_vector() {
    echo ""
    echo "Uninstalling Vector..."
    
    if [[ "$OS_TYPE" == "macOS" ]]; then
        # Check if installed via Homebrew
        if command -v brew &> /dev/null && brew list vector &> /dev/null; then
            echo "  - Uninstalling Vector via Homebrew..."
            brew uninstall vector
            brew untap vectordotdev/brew 2>/dev/null || true
            echo "  ✓ Homebrew package removed"
        fi
        
        # Remove binary if installed via official installer
        if [[ -f "/usr/local/bin/vector" ]]; then
            echo "  - Removing /usr/local/bin/vector"
            sudo rm -f /usr/local/bin/vector
        fi
        
        if [[ -f "/opt/homebrew/bin/vector" ]]; then
            echo "  - Removing /opt/homebrew/bin/vector"
            sudo rm -f /opt/homebrew/bin/vector
        fi
        
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Remove binary
        if [[ -f "/usr/local/bin/vector" ]]; then
            echo "  - Removing /usr/local/bin/vector"
            sudo rm -f /usr/local/bin/vector
        fi
        
        if [[ -f "/usr/bin/vector" ]]; then
            echo "  - Removing /usr/bin/vector"
            sudo rm -f /usr/bin/vector
        fi
        
        # Remove package if installed via package manager
        if command -v apt-get &> /dev/null && dpkg -l | grep -q vector; then
            echo "  - Removing Vector via apt..."
            sudo apt-get remove -y vector
        elif command -v yum &> /dev/null && yum list installed | grep -q vector; then
            echo "  - Removing Vector via yum..."
            sudo yum remove -y vector
        fi
    fi
    
    echo "  ✓ Vector binary removed"
}

# Function to remove configuration and data directories
remove_directories() {
    echo ""
    echo "Removing configuration and data directories..."
    
    # Common directories to check
    declare -a DIRS=(
        "/etc/vector"
        "/usr/local/etc/vector"
        "/opt/homebrew/etc/vector"
        "/var/lib/vector"
        "/usr/local/var/lib/vector"
        "/opt/homebrew/var/lib/vector"
        "/var/log/vector.log"
        "/usr/local/var/log/vector.log"
        "/opt/homebrew/var/log/vector.log"
    )
    
    for dir in "${DIRS[@]}"; do
        if [[ -e "$dir" ]]; then
            echo "  - Removing $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    echo "  ✓ Directories cleaned up"
}

# Function to verify cleanup
verify_cleanup() {
    echo ""
    echo "Verifying cleanup..."
    
    # Check for running processes
    if pgrep -x vector &> /dev/null; then
        echo "  ⚠️  Warning: Vector process still running"
        echo "     PIDs: $(pgrep -x vector | tr '\n' ' ')"
    else
        echo "  ✓ No Vector processes running"
    fi
    
    # Check for binary
    if command -v vector &> /dev/null; then
        echo "  ⚠️  Warning: Vector binary still in PATH"
        echo "     Location: $(which vector)"
    else
        echo "  ✓ Vector binary not in PATH"
    fi
    
    # Check if Homebrew still lists it
    if [[ "$OS_TYPE" == "macOS" ]] && command -v brew &> /dev/null; then
        if brew list vector &> /dev/null; then
            echo "  ⚠️  Warning: Homebrew still lists Vector as installed"
        else
            echo "  ✓ Vector not in Homebrew packages"
        fi
    fi
}

# Main execution
main() {
    echo "This script will completely remove Vector from your system."
    echo "This includes:"
    echo "  - Vector service (LaunchDaemon/systemd)"
    echo "  - Vector binary"
    echo "  - Configuration files"
    echo "  - Data directories"
    echo "  - Log files"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
    
    echo ""
    
    cleanup_services
    remove_service_units
    uninstall_vector
    remove_directories
    verify_cleanup
    
    echo ""
    echo "========================================"
    echo "✓ Vector cleanup completed"
    echo "========================================"
}

# Run main function
main
