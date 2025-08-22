#!/bin/bash
# Local Installation Script for update-noti

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/update-noti"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash install-local.sh"

# Check if binary exists
[ ! -f "$SCRIPT_DIR/update-noti" ] && error "Binary not found: $SCRIPT_DIR/update-noti"

# Clean install
log "Installing update-noti from local binary..."
rm -rf "$INSTALL_DIR" && mkdir -p "$INSTALL_DIR"

# Copy binary
cp "$SCRIPT_DIR/update-noti" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/update-noti"
log "Binary installed successfully"

cd "$INSTALL_DIR"

# Create config
cat > config.json << 'EOF'
{
  "auto_update": ["tailscale", "netdata"],
  "slack_webhook": "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
}
EOF

# Self-updater
cat > update.sh << 'EOF'
#!/bin/bash
cd /opt/update-noti

# Try to update from GitHub releases first
BINARY_URL="https://github.com/raf181/Package-Updates-Noty/releases/latest/download/update-noti"
BINARY_UPDATED=false

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o update-noti.new "$BINARY_URL" 2>/dev/null && [ -s update-noti.new ]; then
        chmod +x update-noti.new && mv update-noti.new update-noti
        BINARY_UPDATED=true
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO update-noti.new "$BINARY_URL" 2>/dev/null && [ -s update-noti.new ]; then
        chmod +x update-noti.new && mv update-noti.new update-noti
        BINARY_UPDATED=true
    fi
fi

# If GitHub update failed, keep using current binary
exec ./update-noti
EOF
chmod +x update.sh

# Setup systemd timer
cat > /etc/systemd/system/update-noti.service << EOF
[Unit]
Description=Update Notification System
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/update.sh
User=root
EOF

cat > /etc/systemd/system/update-noti.timer << EOF
[Unit]
Description=Daily update check at midnight
Requires=update-noti.service

[Timer]
OnCalendar=daily
OnBootSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now update-noti.timer

# Cron fallback
(crontab -l 2>/dev/null | grep -v update-noti; echo "0 0 * * * cd $INSTALL_DIR && ./update.sh") | crontab -

# Test installation
log "Testing installation..."
if timeout 30 ./update-noti --install-complete 2>/dev/null; then
    TEST_STATUS="✅ Installation completed and notification sent"
else
    TEST_STATUS="⚠️ Installation completed but notification failed"
    warn "Installation notification may have failed - check Slack webhook configuration"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 UPDATE-NOTI INSTALLED! 🎉${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📍 Location: $INSTALL_DIR"
echo -e "⏰ Schedule: Daily at 00:00 + boot backup"
echo -e "🔄 Auto-update: Enabled"
echo -e "🧪 Test: cd $INSTALL_DIR && ./update.sh"
echo -e "📝 Config: $INSTALL_DIR/config.json"
echo -e "$TEST_STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📝 NEXT STEPS:${NC}"
echo -e "1. Edit $INSTALL_DIR/config.json to set your Slack webhook URL"
echo -e "2. Test: cd $INSTALL_DIR && ./update.sh"
