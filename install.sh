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
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Get system information for Slack notification
get_system_info() {
    local hostname=$(hostname)
    local ip="Unknown"
    
    # Get IP address
    if command -v curl >/dev/null 2>&1; then
        ip=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    fi
    
    # Get current time
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Get OS info
    local os_info=$(uname -s)
    if [ -f /etc/os-release ]; then
        os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)
    fi
    
    echo "$hostname|$ip|$current_time|$os_info"
}

# Send Slack notification
send_slack_notification() {
    local message="$1"
    local payload="{\"text\":\"$message\"}"
    
    if command -v curl >/dev/null 2>&1; then
        local response=$(curl -X POST -H 'Content-type: application/json' \
                            --data "$payload" \
                            "$SLACK_WEBHOOK" 2>/dev/null)
        if [ "$response" = "ok" ]; then
            return 0
        else
            warn "Slack notification failed: $response"
            return 1
        fi
    else
        warn "curl not available for Slack notification"
        return 1
    fi
}

# Check root
[[ $EUID -ne 0 ]] && error "Run as root: curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | sudo bash"

# Get system info for notifications
SYSTEM_INFO=$(get_system_info)
IFS='|' read -r HOSTNAME IP_ADDR INSTALL_TIME OS_INFO <<< "$SYSTEM_INFO"

# Clean install
log "Installing update-noti binary from GitHub releases..."
rm -rf "$INSTALL_DIR" && mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

# Only try to download binary from GitHub releases
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o update-noti "$BINARY_URL" 2>/dev/null && [ -s update-noti ]; then
        chmod +x update-noti
        log "Binary downloaded and installed successfully"
    else
        error "Failed to download binary from GitHub releases. Binary may not be available yet."
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO update-noti "$BINARY_URL" 2>/dev/null && [ -s update-noti ]; then
        chmod +x update-noti
        log "Binary downloaded and installed successfully"
    else
        error "Failed to download binary from GitHub releases. Binary may not be available yet."
    fi
else
    error "curl or wget required for installation"
fi

# Create config
cat > config.json << 'EOF'
{
  "auto_update": ["tailscale", "netdata"]
}
EOF

# Self-updater - only use binary from GitHub releases
cat > update.sh << EOF
#!/bin/bash
cd /opt/update-noti
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o update-noti.new "$BINARY_URL" 2>/dev/null && [ -s update-noti.new ]; then
        chmod +x update-noti.new && mv update-noti.new update-noti
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO update-noti.new "$BINARY_URL" 2>/dev/null && [ -s update-noti.new ]; then
        chmod +x update-noti.new && mv update-noti.new update-noti
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

# Test
log "Testing installation..."
if timeout 30 ./update-noti >/dev/null 2>&1; then
    TEST_STATUS="✅ Test passed"
else
    TEST_STATUS="⚠️ Test timeout (normal if no updates)"
    warn "Test timeout (normal if no updates)"
fi

# Send installation success notification to Slack
SLACK_MESSAGE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 *UPDATE-NOTI INSTALLED!* 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 **Time:** \`$INSTALL_TIME\`
🖥️ **Host:** \`$HOSTNAME\` (\`$IP_ADDR\`)
💻 **OS:** \`$OS_INFO\`
📍 **Location:** \`$INSTALL_DIR\`
📦 **Method:** Binary from GitHub releases
$TEST_STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏰ **Schedule:** Daily at 00:00 + boot backup
🔄 **Auto-update:** Enabled
📝 **Config:** \`$INSTALL_DIR/config.json\`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log "Sending installation notification to Slack..."
if send_slack_notification "$SLACK_MESSAGE"; then
    SLACK_STATUS="📨 Slack notification sent"
else
    SLACK_STATUS="⚠️ Slack notification failed (check webhook)"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 UPDATE-NOTI INSTALLED! 🎉${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📍 Location: $INSTALL_DIR"
echo -e "🖥️ Host: $HOSTNAME ($IP_ADDR)"
echo -e "⏰ Schedule: Daily at 00:00 + boot backup"
echo -e "🔄 Auto-update: Enabled"
echo -e "🧪 Test: cd $INSTALL_DIR && ./update.sh"
echo -e "📝 Config: $INSTALL_DIR/config.json"
echo -e "$SLACK_STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"