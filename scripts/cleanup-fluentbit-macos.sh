#!/bin/bash
###############################################################################
# O.A.S.I.S. Fluent Bit Agent Cleanup Script (macOS)
# 
# This script completely removes Fluent Bit and all related configurations
# from the system.
#
# Prerequisites:
#   - sudo access
#
# Usage:
#   sudo ./cleanup-fluentbit-macos.sh
#
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_DIR="/usr/local/etc/fluent-bit"
LOG_DIR="/usr/local/var/log/fluent-bit"
PLIST_NAME="io.fluentbit.agent"
PLIST_PATH="/Library/LaunchDaemons/${PLIST_NAME}.plist"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

stop_service() {
    log_info "Stopping Fluent Bit service..."
    
    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        log_success "Service stopped and removed"
    else
        log_info "Service not found"
    fi
}

uninstall_package() {
    log_info "Uninstalling Fluent Bit package..."
    
    if command -v brew &> /dev/null; then
        if su - ${SUDO_USER} -c "brew list fluent-bit &>/dev/null"; then
            su - ${SUDO_USER} -c "brew uninstall fluent-bit"
            log_success "Package uninstalled"
        else
            log_info "Package not installed via Homebrew"
        fi
    else
        log_info "Homebrew not found, skipping package removal"
    fi
}

remove_configs() {
    log_info "Removing configuration files..."
    
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        log_success "Configuration removed: $CONFIG_DIR"
    else
        log_info "Configuration directory not found"
    fi
}

remove_logs() {
    log_info "Removing log files..."
    
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        log_success "Logs removed: $LOG_DIR"
    else
        log_info "Log directory not found"
    fi
}

print_summary() {
    echo
    log_success "=== Cleanup Complete ==="
    echo
    log_info "Fluent Bit has been completely removed from this system."
    echo
}

main() {
    echo
    log_info "=== O.A.S.I.S. Fluent Bit Cleanup (macOS) ==="
    echo
    
    read -p "This will completely remove Fluent Bit. Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
    
    check_root
    
    stop_service
    uninstall_package
    remove_configs
    remove_logs
    
    print_summary
}

# Run main function
main
