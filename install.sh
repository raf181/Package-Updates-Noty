#!/bin/bash
# Update Notification System - Robust GitHub Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash

set -euo pipefail
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/update-noti"
GITHUB_REPO="raf181/Package-Updates-Noty"
BINARY_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/update-noti"
TEMP_DIR="/tmp/update-noti-install-$$"

log() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; cleanup_temp; exit 1; }

# Cleanup function
cleanup_temp() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}

# Set up cleanup trap
trap cleanup_temp EXIT INT TERM

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | sudo bash"
fi

# System compatibility checks
log "Checking system compatibility..."

# Check for required commands
for cmd in systemctl crontab; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' not found"
    fi
done

# Check for curl or wget
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    error "Neither curl nor wget found. At least one is required for installation."
fi

# Create secure temporary directory
log "Creating temporary directory..."
mkdir -p "$TEMP_DIR"
chmod 700 "$TEMP_DIR"

# Clean installation directory
log "Preparing installation directory..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Work in temp directory to avoid path issues
cd "$TEMP_DIR"

# Download and install the binary/script
log "Downloading update-noti..."
BINARY_DOWNLOADED=false

# Try binary download first
if command -v curl >/dev/null 2>&1; then
    log "Attempting binary download with curl..."
    if curl -fsSL --connect-timeout 30 --max-time 300 -o "update-noti" "$BINARY_URL" && [ -s "update-noti" ]; then
        # Verify it's actually a binary (not an HTML error page)
        if file "update-noti" | grep -q "ELF\|executable"; then
            chmod +x "update-noti"
            log "Binary downloaded successfully"
            BINARY_DOWNLOADED=true
        else
            warn "Downloaded file is not a valid binary"
            rm -f "update-noti"
        fi
    else
        warn "Binary download with curl failed"
    fi
elif command -v wget >/dev/null 2>&1; then
    log "Attempting binary download with wget..."
    if wget --timeout=30 --tries=3 -qO "update-noti" "$BINARY_URL" && [ -s "update-noti" ]; then
        # Verify it's actually a binary (not an HTML error page)
        if file "update-noti" | grep -q "ELF\|executable"; then
            chmod +x "update-noti"
            log "Binary downloaded successfully"
            BINARY_DOWNLOADED=true
        else
            warn "Downloaded file is not a valid binary"
            rm -f "update-noti"
        fi
    else
        warn "Binary download with wget failed"
    fi
fi

# If binary download failed, try Python script fallback
if [ "$BINARY_DOWNLOADED" = false ]; then
    warn "Binary not available, using Python script fallback..."
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required but not found. Please install Python 3 or ensure binary release is available."
    fi
    
    # Download Python script
    SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/update_noti.py"
    log "Downloading Python script..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 30 --max-time 300 -o "update_noti.py" "$SCRIPT_URL" || error "Failed to download Python script with curl"
    elif command -v wget >/dev/null 2>&1; then
        wget --timeout=30 --tries=3 -qO "update_noti.py" "$SCRIPT_URL" || error "Failed to download Python script with wget"
    else
        error "Neither curl nor wget available for downloading"
    fi
    
    # Verify script was downloaded
    if [ ! -s "update_noti.py" ]; then
        error "Python script download failed or file is empty"
    fi
    
    # Create wrapper script
    cat > "update-noti" << 'EOF'
#!/bin/bash
# Python wrapper script for update-noti
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Python script exists
if [ ! -f "update_noti.py" ]; then
    echo "Error: update_noti.py not found" >&2
    exit 1
fi

# Execute Python script
exec python3 "update_noti.py" "$@"
EOF
    chmod +x "update-noti"
    log "Python script installed with wrapper"
fi

# Copy files to installation directory
log "Installing files to $INSTALL_DIR..."
cp "update-noti" "$INSTALL_DIR/"
if [ -f "update_noti.py" ]; then
    cp "update_noti.py" "$INSTALL_DIR/"
fi

# Verify installation
if [ ! -f "$INSTALL_DIR/update-noti" ] || [ ! -x "$INSTALL_DIR/update-noti" ]; then
    error "Installation verification failed - update-noti not found or not executable"
fi

log "Files installed successfully"

# Create configuration file
log "Creating configuration file..."
cat > "$INSTALL_DIR/config.json" << 'EOF'
{
  "auto_update": ["tailscale", "netdata"],
  "slack_webhook": "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
}
EOF

# Verify config was created
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    error "Failed to create configuration file"
fi

# Create self-updater script
log "Creating self-updater script..."
cat > "$INSTALL_DIR/update.sh" << EOF
#!/bin/bash
# Self-updater and runner for update-noti
set -e

# Change to installation directory
cd "/opt/update-noti" || exit 1

# Function to log messages
log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >&2; }

# Try to update to latest binary version
log "Checking for updates..."
BINARY_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/update-noti"
BINARY_UPDATED=false

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL --connect-timeout 10 --max-time 60 -o "update-noti.new" "\$BINARY_URL" 2>/dev/null; then
        if [ -s "update-noti.new" ] && file "update-noti.new" 2>/dev/null | grep -q "ELF\|executable"; then
            chmod +x "update-noti.new"
            mv "update-noti.new" "update-noti"
            log "Binary updated successfully"
            BINARY_UPDATED=true
        else
            rm -f "update-noti.new" 2>/dev/null || true
        fi
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget --timeout=10 --tries=1 -qO "update-noti.new" "\$BINARY_URL" 2>/dev/null; then
        if [ -s "update-noti.new" ] && file "update-noti.new" 2>/dev/null | grep -q "ELF\|executable"; then
            chmod +x "update-noti.new"
            mv "update-noti.new" "update-noti"
            log "Binary updated successfully"
            BINARY_UPDATED=true
        else
            rm -f "update-noti.new" 2>/dev/null || true
        fi
    fi
fi

# If binary update failed and we're using Python script, try to update that
if [ "\$BINARY_UPDATED" = false ] && [ -f "update_noti.py" ]; then
    log "Attempting to update Python script..."
    SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/update_noti.py"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --connect-timeout 10 --max-time 60 -o "update_noti.py.new" "\$SCRIPT_URL" 2>/dev/null && [ -s "update_noti.py.new" ]; then
            mv "update_noti.py.new" "update_noti.py"
            log "Python script updated successfully"
        else
            rm -f "update_noti.py.new" 2>/dev/null || true
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --timeout=10 --tries=1 -qO "update_noti.py.new" "\$SCRIPT_URL" 2>/dev/null && [ -s "update_noti.py.new" ]; then
            mv "update_noti.py.new" "update_noti.py"
            log "Python script updated successfully"
        else
            rm -f "update_noti.py.new" 2>/dev/null || true
        fi
    fi
fi

# Execute the update check
log "Running update check..."
exec ./update-noti
EOF

chmod +x "$INSTALL_DIR/update.sh"

# Verify updater was created
if [ ! -f "$INSTALL_DIR/update.sh" ] || [ ! -x "$INSTALL_DIR/update.sh" ]; then
    error "Failed to create update.sh script"
fi

# Setup systemd service and timer
log "Setting up systemd service and timer..."

# Create service file
cat > "/etc/systemd/system/update-noti.service" << EOF
[Unit]
Description=Update Notification System
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/update.sh
User=root
TimeoutStartSec=300
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR
NoNewPrivileges=false
EOF

# Create timer file
cat > "/etc/systemd/system/update-noti.timer" << EOF
[Unit]
Description=Daily update check at midnight
Requires=update-noti.service

[Timer]
OnCalendar=daily
OnBootSec=5min
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable timer
log "Enabling systemd timer..."
systemctl daemon-reload || error "Failed to reload systemd daemon"
systemctl enable update-noti.timer || error "Failed to enable systemd timer"
systemctl start update-noti.timer || error "Failed to start systemd timer"

# Verify timer is active
if ! systemctl is-active --quiet update-noti.timer; then
    error "Systemd timer is not active"
fi

log "Systemd timer configured and started successfully"

# Setup cron fallback
log "Setting up cron fallback..."

# Create cron entry with better error handling
TEMP_CRON="$TEMP_DIR/crontab.tmp"
(crontab -l 2>/dev/null | grep -v update-noti || true) > "$TEMP_CRON"
echo "0 0 * * * cd $INSTALL_DIR && ./update.sh >/dev/null 2>&1" >> "$TEMP_CRON"

if crontab "$TEMP_CRON"; then
    log "Cron fallback configured successfully"
else
    warn "Failed to configure cron fallback (not critical)"
fi

# Test installation
log "Testing installation..."
cd "$INSTALL_DIR" || error "Cannot change to installation directory"

# Test basic functionality
if ! ./update-noti --help >/dev/null 2>&1 && [ $? -ne 1 ]; then
    error "Installation verification failed - binary/script is not working"
fi

# Try to send installation notification
log "Sending installation notification..."
if timeout 45 ./update-noti --install-complete 2>/dev/null; then
    TEST_STATUS="✅ Installation completed and notification sent"
    log "Installation notification sent successfully"
else
    TEST_STATUS="⚠️ Installation completed but notification failed"
    warn "Installation notification failed (check Slack webhook configuration)"
fi

# Display final status
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 UPDATE-NOTI INSTALLATION COMPLETE! 🎉${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📍 ${GREEN}Installation Directory:${NC} $INSTALL_DIR"
echo -e "📦 ${GREEN}Method:${NC} $([ "$BINARY_DOWNLOADED" = true ] && echo "Binary" || echo "Python Script")"
echo -e "⏰ ${GREEN}Schedule:${NC} Daily at 00:00 + 5min after boot"
echo -e "🔄 ${GREEN}Auto-update:${NC} Enabled"
echo -e "📝 ${GREEN}Configuration:${NC} $INSTALL_DIR/config.json"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "$TEST_STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${YELLOW}📋 NEXT STEPS:${NC}"
echo -e "  1. Edit the configuration: ${BLUE}nano $INSTALL_DIR/config.json${NC}"
echo -e "  2. Set your Slack webhook URL in the config file"
echo -e "  3. Test manually: ${BLUE}cd $INSTALL_DIR && ./update.sh${NC}"
echo -e "  4. Check status: ${BLUE}systemctl status update-noti.timer${NC}"
echo
echo -e "${GREEN}✅ Installation completed successfully!${NC}"
echo

# Clean up
log "Cleaning up temporary files..."
cleanup_temp
log "Installation process completed"