#!/bin/bash
set -e

# Package Updates Notifier - Enhanced Installer
# Installs binary from GitHub releases with Python fallback
# Supports automatic Slack webhook configuration

REPO="raf181/Package-Updates-Noty"
INSTALL_DIR="/opt/update-noti"
SERVICE_NAME="update-noti"
    
TEMP_DIR=$(mktemp -d -t update-noti-install-XXXXXX)

# Configuration variables - use environment variables if already set
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
AUTO_UPDATE_PACKAGES="${AUTO_UPDATE_PACKAGES:-}"
SKIP_CONFIG_PROMPT=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook)
            SLACK_WEBHOOK_URL="$2"
            shift 2
            ;;
        --webhook=*)
            SLACK_WEBHOOK_URL="${1#*=}"
            shift
            ;;
        --packages)
            AUTO_UPDATE_PACKAGES="$2"
            shift 2
            ;;
        --packages=*)
            AUTO_UPDATE_PACKAGES="${1#*=}"
            shift
            ;;
        --skip-config)
            SKIP_CONFIG_PROMPT=true
            shift
            ;;
        --help|-h)
            echo "Package Updates Notifier Installer"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --webhook=URL        Set Slack webhook URL automatically"
            echo "  --packages=LIST      Comma-separated list of packages to auto-update"
            echo "  --skip-config        Skip configuration prompts (use defaults)"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  SLACK_WEBHOOK_URL    Slack webhook URL"
            echo "  AUTO_UPDATE_PACKAGES Comma-separated package list"
            echo ""
            echo "Examples:"
            echo "  $0 --webhook=https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
            echo "  $0 --webhook=YOUR_URL --packages=nginx,docker.io,tailscale"
            echo "  SLACK_WEBHOOK_URL=YOUR_URL $0 --skip-config"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Use environment variables if not set via arguments
# Environment variables should already be inherited from parent shell

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup on exit
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (use sudo)"
    exit 1
fi

# Detect system info
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        OS=$(uname -s)
        VERSION=$(uname -r)
    fi
    log "Detected system: $OS $VERSION"
}

# Download with retry logic
download_with_retry() {
    local url="$1"
    local output="$2"
    local retries=3
    local delay=2
    
    for ((i=1; i<=retries; i++)); do
        log "Download attempt $i/$retries: $url"
        
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output"; then
                return 0
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget --timeout=60 --tries=1 -q "$url" -O "$output"; then
                return 0
            fi
        else
            error "Neither curl nor wget is available"
            return 1
        fi
        
        if [ $i -lt $retries ]; then
            warning "Download failed, retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi
    done
    
    return 1
}

# Verify binary is valid
verify_binary() {
    local binary="$1"
    
    if [ ! -f "$binary" ]; then
        error "Binary file not found: $binary"
        return 1
    fi
    
    if [ ! -x "$binary" ]; then
        error "Binary is not executable: $binary"
        return 1
    fi
    
    # Check if it's a valid ELF executable
    if command -v file >/dev/null 2>&1; then
        if ! file "$binary" | grep -q "ELF\|executable"; then
            error "Downloaded file is not a valid executable"
            return 1
        fi
    fi
    
    # Try to run with --help to verify it works
    if ! timeout 5 "$binary" --help >/dev/null 2>&1; then
        error "Binary fails to execute properly"
        return 1
    fi
    
    success "Binary verification passed"
    return 0
}

# Install binary from GitHub releases
install_binary() {
    log "Attempting to download binary from GitHub releases..."
    
    cd "$TEMP_DIR"
    
    # Try to download binary
    local binary_url="https://github.com/$REPO/releases/latest/download/update-noti"
    
    if download_with_retry "$binary_url" "update-noti"; then
        chmod +x update-noti
        
        if verify_binary "./update-noti"; then
            log "Installing binary to $INSTALL_DIR"
            mkdir -p "$INSTALL_DIR"
            cp update-noti "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/update-noti"
            success "Binary installed successfully"
            return 0
        else
            warning "Binary verification failed, will try Python script fallback"
        fi
    else
        warning "Binary download failed, will try Python script fallback"
    fi
    
    return 1
}

# Install Python script as fallback
install_python_script() {
    log "Installing Python script fallback..."
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is not installed. Please install Python 3 first."
        return 1
    fi
    
    cd "$TEMP_DIR"
    
    # Download Python script
    local script_url="https://raw.githubusercontent.com/$REPO/main/update_noti.py"
    
    if download_with_retry "$script_url" "update_noti.py"; then
        log "Installing Python script to $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        cp update_noti.py "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/update_noti.py"
        
        # Create wrapper script for Python
        cat > "$INSTALL_DIR/update-noti" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec python3 update_noti.py "$@"
EOF
        chmod +x "$INSTALL_DIR/update-noti"
        
        success "Python script installed successfully"
        return 0
    else
        error "Failed to download Python script"
        return 1
    fi
}

# Create default configuration
create_config() {
    log "Creating configuration file..."
    
    # Ensure environment variables are properly inherited
    if [ -z "$SLACK_WEBHOOK_URL" ] && [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
    fi
    
    # Determine auto-update packages
    local packages='"tailscale"'
    if [ -n "$AUTO_UPDATE_PACKAGES" ]; then
        # Convert comma-separated list to JSON array format
        packages=$(echo "$AUTO_UPDATE_PACKAGES" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/'"/')
    fi
    
    # Determine webhook URL
    local webhook_url="https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        webhook_url="$SLACK_WEBHOOK_URL"
        log "Using provided Slack webhook URL"
        # Automatically skip config prompts when webhook is provided
        SKIP_CONFIG_PROMPT=true
    fi
    
    # Create config file
    cat > "$INSTALL_DIR/config.json" << EOF
{
  "auto_update": [
    $packages
  ],
  "slack_webhook": "$webhook_url"
}
EOF
    
    success "Configuration file created: $INSTALL_DIR/config.json"
    
    # Show configuration status
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        success "✅ Slack webhook configured automatically"
    else
        warning "⚠️  Please edit $INSTALL_DIR/config.json to configure your Slack webhook"
    fi
    
    # Interactive configuration if not skipped
    if [ "$SKIP_CONFIG_PROMPT" = false ] && [ -z "$SLACK_WEBHOOK_URL" ]; then
        echo
        echo -e "${YELLOW}Would you like to configure your Slack webhook now? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            configure_webhook_interactive
        fi
    fi
}

# Interactive webhook configuration
configure_webhook_interactive() {
    echo
    echo -e "${BLUE}📝 Slack Webhook Configuration${NC}"
    echo "Please enter your Slack webhook URL:"
    echo "(Format: https://hooks.slack.com/services/YOUR/WEBHOOK/URL)"
    echo
    read -r webhook_input
    
    if [ -n "$webhook_input" ] && [[ "$webhook_input" == https://hooks.slack.com/services/* ]]; then
        # Update config file with new webhook
        if command -v jq >/dev/null 2>&1; then
            # Use jq if available for better JSON handling
            jq --arg webhook "$webhook_input" '.slack_webhook = $webhook' "$INSTALL_DIR/config.json" > "$INSTALL_DIR/config.json.tmp" && mv "$INSTALL_DIR/config.json.tmp" "$INSTALL_DIR/config.json"
        else
            # Fallback to sed
            sed -i "s|\"slack_webhook\": \".*\"|\"slack_webhook\": \"$webhook_input\"|g" "$INSTALL_DIR/config.json"
        fi
        success "✅ Slack webhook configured successfully"
        
        # Test the webhook
        echo
        echo -e "${BLUE}Would you like to test the webhook now? (y/n)${NC}"
        read -r test_response
        if [[ "$test_response" =~ ^[Yy]$ ]]; then
            test_slack_webhook "$webhook_input"
        fi
    else
        warning "Invalid webhook URL format. You can configure it later in $INSTALL_DIR/config.json"
    fi
}

# Test Slack webhook
test_slack_webhook() {
    local webhook_url="$1"
    log "Testing Slack webhook..."
    
    local test_message='{"text":"🎉 *Package Updates Notifier* installed successfully!\n✅ Webhook test completed - your notifications are working!"}'
    
    if curl -X POST -H 'Content-type: application/json' --data "$test_message" "$webhook_url" --silent --show-error | grep -q "ok"; then
        success "✅ Slack webhook test successful! Check your Slack channel."
    else
        warning "⚠️ Slack webhook test failed. Please check your webhook URL."
    fi
}

# Create update wrapper script
create_update_wrapper() {
    log "Creating update wrapper script..."
    
    cat > "$INSTALL_DIR/update.sh" << EOF
#!/bin/bash
# Auto-update wrapper for Package Updates Notifier

SCRIPT_DIR="\$(dirname "\$0")"
cd "\$SCRIPT_DIR"

# Auto-update binary if available
update_binary() {
    echo "Checking for updates..."
    
    # Download latest binary
    TEMP_BINARY=\$(mktemp)
    if curl -fsSL "https://github.com/$REPO/releases/latest/download/update-noti" -o "\$TEMP_BINARY" 2>/dev/null; then
        chmod +x "\$TEMP_BINARY"
        
        # Verify new binary
        if "\$TEMP_BINARY" --help >/dev/null 2>&1; then
            cp "\$TEMP_BINARY" "./update-noti"
            echo "✅ Binary updated successfully"
        else
            echo "⚠️ New binary verification failed, keeping current version"
        fi
        rm -f "\$TEMP_BINARY"
    else
        echo "⚠️ Failed to check for updates"
    fi
}

# Auto-update before running
update_binary

# Run the main application
exec "./update-noti" "\$@"
EOF
    
    chmod +x "$INSTALL_DIR/update.sh"
    success "Update wrapper created: $INSTALL_DIR/update.sh"
}

# Setup systemd service
setup_systemd() {
    log "Setting up systemd service and timer..."
    
    # Create service file
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Package Updates Notifier
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/update.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file
    cat > "/etc/systemd/system/${SERVICE_NAME}.timer" << EOF
[Unit]
Description=Run Package Updates Notifier daily
Requires=${SERVICE_NAME}.service

[Timer]
OnCalendar=daily
OnBootSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable and start timer
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}.timer"
    systemctl start "${SERVICE_NAME}.timer"
    
    success "Systemd service configured and started"
}

# Setup cron fallback
setup_cron_fallback() {
    log "Setting up cron fallback..."
    
    # Add cron job (fallback if systemd fails)
    local cron_line="0 0 * * * root cd $INSTALL_DIR && ./update.sh >/dev/null 2>&1"
    
    if ! grep -Fxq "$cron_line" /etc/crontab; then
        echo "$cron_line" >> /etc/crontab
        success "Cron fallback configured"
    else
        log "Cron fallback already configured"
    fi
}

# Send installation notification
send_install_notification() {
    log "Sending installation notification..."
    
    if [ -x "$INSTALL_DIR/update-noti" ]; then
        "$INSTALL_DIR/update-noti" --install-complete || true
    fi
}

# Main installation process
main() {
    log "🚀 Starting Package Updates Notifier installation..."
    
    detect_system
    
    # Try binary installation first, fallback to Python script
    if ! install_binary; then
        if ! install_python_script; then
            error "Both binary and Python script installation failed"
            exit 1
        fi
    fi
    
    # Create configuration and scripts
    create_config
    create_update_wrapper
    
    # Setup scheduling
    if command -v systemctl >/dev/null 2>&1; then
        setup_systemd
    else
        log "Systemd not available, using cron only"
    fi
    
    setup_cron_fallback
    
    # Send notification
    send_install_notification
    
    # Final success message
    echo
    success "🎉 Installation completed successfully!"
    echo
    echo -e "${BLUE}📁 Installation directory:${NC} $INSTALL_DIR"
    echo -e "${BLUE}📝 Configuration file:${NC} $INSTALL_DIR/config.json"
    echo -e "${BLUE}🔧 Update script:${NC} $INSTALL_DIR/update.sh"
    echo
    
    # Show conditional next steps based on webhook configuration
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        echo -e "${GREEN}✅ Slack webhook configured automatically - ready to use!${NC}"
        echo -e "${GREEN}📋 Next steps:${NC}"
        echo "  1. Customize auto-update packages in $INSTALL_DIR/config.json (optional)"
        echo "  2. Test manually: cd $INSTALL_DIR && ./update.sh"
    else
        echo -e "${YELLOW}⚠️  IMPORTANT: Configure your Slack webhook in $INSTALL_DIR/config.json${NC}"
        echo -e "${GREEN}📋 Next steps:${NC}"
        echo "  1. Edit $INSTALL_DIR/config.json with your Slack webhook URL"
        echo "  2. Customize auto-update packages in the config"
        echo "  3. Test manually: cd $INSTALL_DIR && ./update.sh"
    fi
    
    echo
    echo -e "${BLUE}⏰ Scheduled to run daily at 00:00 with 5-minute boot delay${NC}"
    echo
}

# Run main function
main "$@"