#!/bin/bash
# Local Installation Script for update-noti

set -euo pipefail
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/update-noti"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo bash install-local.sh"
fi

# Check if binary exists and is executable
if [ ! -f "$SCRIPT_DIR/update-noti" ]; then
    error "Binary not found: $SCRIPT_DIR/update-noti"
fi

if [ ! -x "$SCRIPT_DIR/update-noti" ]; then
    error "Binary is not executable: $SCRIPT_DIR/update-noti"
fi

# System checks
log "Checking system compatibility..."
for cmd in systemctl crontab; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' not found"
    fi
done

# Clean installation
log "Installing update-noti from local binary..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy and verify binary
cp "$SCRIPT_DIR/update-noti" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/update-noti"

# Verify installation
if [ ! -f "$INSTALL_DIR/update-noti" ] || [ ! -x "$INSTALL_DIR/update-noti" ]; then
    error "Binary installation verification failed"
fi

log "Binary installed and verified successfully"

# Create config
log "Creating configuration..."
cat > "$INSTALL_DIR/config.json" << 'EOF'
{
  "auto_update": ["tailscale", "netdata"],
  "slack_webhook": "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
}
EOF

if [ ! -f "$INSTALL_DIR/config.json" ]; then
    error "Failed to create configuration file"
fi

# Self-updater
log "Creating self-updater..."
cat > "$INSTALL_DIR/update.sh" << 'EOF'
#!/bin/bash
# Self-updater for locally installed update-noti
set -e

cd /opt/update-noti || exit 1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2; }

# Try to update from GitHub releases first
log "Checking for updates..."
BINARY_URL="https://github.com/raf181/Package-Updates-Noty/releases/latest/download/update-noti"
BINARY_UPDATED=false

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL --connect-timeout 10 --max-time 60 -o "update-noti.new" "$BINARY_URL" 2>/dev/null; then
        if [ -s "update-noti.new" ] && file "update-noti.new" 2>/dev/null | grep -q "ELF\|executable"; then
            chmod +x "update-noti.new"
            mv "update-noti.new" "update-noti"
            log "Binary updated from GitHub releases"
            BINARY_UPDATED=true
        else
            rm -f "update-noti.new" 2>/dev/null || true
        fi
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget --timeout=10 --tries=1 -qO "update-noti.new" "$BINARY_URL" 2>/dev/null; then
        if [ -s "update-noti.new" ] && file "update-noti.new" 2>/dev/null | grep -q "ELF\|executable"; then
            chmod +x "update-noti.new"
            mv "update-noti.new" "update-noti"
            log "Binary updated from GitHub releases"
            BINARY_UPDATED=true
        else
            rm -f "update-noti.new" 2>/dev/null || true
        fi
    fi
fi

if [ "$BINARY_UPDATED" = false ]; then
    log "Using existing binary (update check failed or not needed)"
fi

# Execute the update check
log "Running package update check..."
exec ./update-noti
EOF

chmod +x "$INSTALL_DIR/update.sh"
if [ ! -x "$INSTALL_DIR/update.sh" ]; then
    error "Failed to create update.sh script"
fi

# Setup systemd timer
log "Setting up systemd service and timer..."
cat > /etc/systemd/system/update-noti.service << EOF
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

cat > /etc/systemd/system/update-noti.timer << EOF
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

# Enable and start systemd timer
systemctl daemon-reload || error "Failed to reload systemd daemon"
systemctl enable update-noti.timer || error "Failed to enable systemd timer"
systemctl start update-noti.timer || error "Failed to start systemd timer"

# Verify timer is active
if ! systemctl is-active --quiet update-noti.timer; then
    error "Systemd timer is not active"
fi

log "Systemd timer configured successfully"

# Cron fallback
log "Setting up cron fallback..."
TEMP_CRON=$(mktemp)
(crontab -l 2>/dev/null | grep -v update-noti || true) > "$TEMP_CRON"
echo "0 0 * * * cd $INSTALL_DIR && ./update.sh >/dev/null 2>&1" >> "$TEMP_CRON"

if crontab "$TEMP_CRON"; then
    log "Cron fallback configured successfully"
else
    warn "Failed to configure cron fallback (not critical)"
fi
rm -f "$TEMP_CRON"

# Test installation
log "Testing installation..."
cd "$INSTALL_DIR" || error "Cannot change to installation directory"

# Test basic functionality
if ! ./update-noti --help >/dev/null 2>&1 && [ $? -ne 1 ]; then
    error "Installation verification failed - binary is not working"
fi

# Test installation notification
log "Testing installation notification..."
if timeout 45 ./update-noti --install-complete 2>/dev/null; then
    TEST_STATUS="✅ Installation completed and notification sent"
    log "Installation notification sent successfully"
else
    TEST_STATUS="⚠️ Installation completed but notification failed"
    warn "Installation notification failed - check Slack webhook configuration"
fi

# Final status display
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 UPDATE-NOTI INSTALLED SUCCESSFULLY! 🎉${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📍 ${GREEN}Installation Directory:${NC} $INSTALL_DIR"
echo -e "📦 ${GREEN}Method:${NC} Local Binary"
echo -e "⏰ ${GREEN}Schedule:${NC} Daily at 00:00 + 5min after boot"
echo -e "🔄 ${GREEN}Auto-update:${NC} Enabled from GitHub releases"
echo -e "📝 ${GREEN}Configuration:${NC} $INSTALL_DIR/config.json"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "$TEST_STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${YELLOW}� NEXT STEPS:${NC}"
echo -e "  1. Edit configuration: ${BLUE}nano $INSTALL_DIR/config.json${NC}"
echo -e "  2. Set your Slack webhook URL in the config file"
echo -e "  3. Test manually: ${BLUE}cd $INSTALL_DIR && ./update.sh${NC}"
echo -e "  4. Check timer status: ${BLUE}systemctl status update-noti.timer${NC}"
echo
echo -e "${GREEN}✅ Local installation completed successfully!${NC}"
