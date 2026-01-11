#!/bin/bash
###############################################################################
# O.A.S.I.S. Fluent Bit Agent Cleanup Script (Linux)
# 
# This script completely removes Fluent Bit and all related configurations
# from the system.
#
# Prerequisites:
#   - Root/sudo access
#
# Usage:
#   sudo ./cleanup-fluentbit.sh
#
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE_NAME="fluent-bit"
CONFIG_DIR="/etc/fluent-bit"
LOG_DIR="/var/log/fluent-bit"
LIB_DIR="/var/lib/fluent-bit"

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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

stop_service() {
    log_info "Stopping Fluent Bit service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log_success "Service stopped"
    else
        log_info "Service is not running"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
        log_success "Service disabled"
    fi
}

remove_service_file() {
    log_info "Removing systemd service file..."
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload
        log_success "Service file removed"
    else
        log_info "Service file not found"
    fi
}

remove_package() {
    log_info "Removing Fluent Bit package..."
    
    case $OS in
        ubuntu|debian)
            if dpkg -l | grep -q fluent-bit; then
                apt-get remove -y fluent-bit
                apt-get purge -y fluent-bit
                apt-get autoremove -y
                
                # Remove repository
                if [ -f /etc/apt/sources.list.d/fluent-bit.list ]; then
                    rm -f /etc/apt/sources.list.d/fluent-bit.list
                fi
                if [ -f /usr/share/keyrings/fluentbit-keyring.gpg ]; then
                    rm -f /usr/share/keyrings/fluentbit-keyring.gpg
                fi
                
                log_success "Package removed"
            else
                log_info "Package not installed"
            fi
            ;;
            
        centos|rhel|fedora)
            if rpm -q fluent-bit &> /dev/null; then
                yum remove -y fluent-bit
                
                # Remove repository
                if [ -f /etc/yum.repos.d/fluent-bit.repo ]; then
                    rm -f /etc/yum.repos.d/fluent-bit.repo
                fi
                
                log_success "Package removed"
            else
                log_info "Package not installed"
            fi
            ;;
            
        *)
            log_warning "Unknown OS: $OS - skipping package removal"
            ;;
    esac
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

remove_data() {
    log_info "Removing data files..."
    
    if [ -d "$LIB_DIR" ]; then
        rm -rf "$LIB_DIR"
        log_success "Data removed: $LIB_DIR"
    else
        log_info "Data directory not found"
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
    log_info "=== O.A.S.I.S. Fluent Bit Cleanup ==="
    echo
    
    read -p "This will completely remove Fluent Bit. Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
    
    check_root
    detect_os
    
    stop_service
    remove_service_file
    remove_package
    remove_configs
    remove_logs
    remove_data
    
    print_summary
}

# Run main function
main
