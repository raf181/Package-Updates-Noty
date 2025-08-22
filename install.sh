#!/bin/bash
# Update Notification System - GitHub Binary Only Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/update-noti"
GITHUB_REPO="raf181/Package-Updates-Noty"
BINARY_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/update-noti"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "Run as root: curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | sudo bash"

# Clean install
log "Installing update-noti..."
rm -rf "$INSTALL_DIR" && mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

# Try to download binary from GitHub releases first
BINARY_DOWNLOADED=false
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o update-noti "$BINARY_URL" 2>/dev/null && [ -s update-noti ]; then
        chmod +x update-noti
        log "Binary downloaded from GitHub releases"
        BINARY_DOWNLOADED=true
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO update-noti "$BINARY_URL" 2>/dev/null && [ -s update-noti ]; then
        chmod +x update-noti
        log "Binary downloaded from GitHub releases"
        BINARY_DOWNLOADED=true
    fi
fi

# If binary download failed, try Python script fallback
if [ "$BINARY_DOWNLOADED" = false ]; then
    warn "Binary not available, falling back to Python script..."
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required for script installation"
    fi
    
    # Download Python script
    SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/update_noti.py"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o update_noti.py "$SCRIPT_URL" || error "Failed to download Python script"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO update_noti.py "$SCRIPT_URL" || error "Failed to download Python script"
    else
        error "curl or wget required for installation"
    fi
    
    # Create wrapper script that runs the Python version
    cat > update-noti << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
exec python3 update_noti.py "$@"
EOF
    chmod +x update-noti
    log "Python script installed with wrapper"
fi

# Create config
cat > config.json << 'EOF'
{
  "auto_update": ["tailscale", "netdata"],
  "slack_webhook": "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
}
EOF

# Self-updater - try binary first, fall back to Python script
cat > update.sh << EOF
#!/bin/bash
cd /opt/update-noti

# Try to update to binary version
BINARY_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/update-noti"
BINARY_UPDATED=false

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o update-noti.new "\$BINARY_URL" 2>/dev/null && [ -s update-noti.new ]; then
        chmod +x update-noti.new && mv update-noti.new update-noti
        BINARY_UPDATED=true
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO update-noti.new "\$BINARY_URL" 2>/dev/null && [ -s update-noti.new ]; then
        chmod +x update-noti.new && mv update-noti.new update-noti
        BINARY_UPDATED=true
    fi
fi

# If binary update failed and we're using Python script, update that
if [ "\$BINARY_UPDATED" = false ] && [ -f "update_noti.py" ]; then
    SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/update_noti.py"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o update_noti.py.new "\$SCRIPT_URL" 2>/dev/null && mv update_noti.py.new update_noti.py
    elif command -v wget >/dev/null 2>&1; then
        wget -qO update_noti.py.new "\$SCRIPT_URL" 2>/dev/null && mv update_noti.py.new update_noti.py
    fi
fi

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

# Test installation and send notification
log "Testing installation..."
if timeout 30 ./update-noti --install-complete 2>/dev/null; then
    TEST_STATUS="✅ Installation completed and notification sent"
else
    TEST_STATUS="⚠️ Installation completed but notification failed"
    warn "Installation notification may have failed"
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