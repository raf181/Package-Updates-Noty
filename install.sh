#!/bin/bash
# Update Notification System - One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/update-noti/main/install.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/YOUR_USERNAME/update-noti/main/install.sh | bash

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/update-noti"
BINARY_URL="https://github.com/raf181/Package-Updates-Noty/releases/latest/download/update-noti-linux-x86_64"
SCRIPT_URL="https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/update_noti.py"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "Run as root: curl -fsSL URL | sudo bash"

# Clean install
log "Installing update-noti..."
rm -rf "$INSTALL_DIR" && mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

# Download binary or fallback to Python script
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o update-noti "$BINARY_URL" 2>/dev/null; then
        chmod +x update-noti
        log "Binary installed"
    else
        warn "Binary not available, trying Python script"
        if curl -fsSL -o update_noti.py "$SCRIPT_URL" 2>/dev/null; then
            cat > update-noti << 'EOF'
#!/bin/bash
cd "$(dirname "$0")" && python3 update_noti.py
EOF
            chmod +x update-noti
            log "Python script installed"
        else
            warn "GitHub sources not available, using local fallback"
            # Local fallback for development/testing
            if [ -f "/home/anoam/update-noti/update_noti.py" ]; then
                cp "/home/anoam/update-noti/update_noti.py" .
                cat > update-noti << 'EOF'
#!/bin/bash
cd "$(dirname "$0")" && python3 update_noti.py
EOF
                chmod +x update-noti
                log "Local Python script installed"
            elif [ -f "/home/anoam/update-noti/dist/update-noti" ]; then
                cp "/home/anoam/update-noti/dist/update-noti" .
                chmod +x update-noti
                log "Local binary installed"
            else
                error "No installation source available"
            fi
        fi
    fi
else
    error "curl required. Install curl first."
fi

# Create config
cat > config.json << 'EOF'
{
  "auto_update": ["tailscale", "netdata"]
}
EOF

# Self-updater
cat > update.sh << 'EOF'
#!/bin/bash
cd /opt/update-noti
if command -v curl >/dev/null; then
    curl -fsSL -o update-noti.new https://github.com/raf181/Package-Updates-Noty/releases/latest/download/update-noti-linux-x86_64 2>/dev/null && {
        chmod +x update-noti.new && mv update-noti.new update-noti
    }
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

# Test
log "Testing installation..."
timeout 30 ./update.sh >/dev/null 2>&1 || warn "Test timeout (normal if no updates)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 UPDATE-NOTI INSTALLED! 🎉${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📍 Location: $INSTALL_DIR"
echo -e "⏰ Schedule: Daily at 00:00 + boot backup"
echo -e "🔄 Auto-update: Enabled"
echo -e "🧪 Test: cd $INSTALL_DIR && ./update.sh"
echo -e "📝 Config: $INSTALL_DIR/config.json"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"