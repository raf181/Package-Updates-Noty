#!/usr/bin/env bash
set -euo pipefail

# Package Updates Notifier - Go Installer (backward-compatible)
# - Installs Go binary from GitHub Releases (linux/amd64, linux/arm64)
# - Preserves flags/envs: --webhook, --packages, --skip-config; SLACK_WEBHOOK_URL, AUTO_UPDATE_PACKAGES
# - Creates update wrapper (update.sh) for self-update behavior
# - Configures systemd service + timer and cron fallback

REPO="raf181/Package-Updates-Noty"
BIN_NAME="update-noti"
INSTALL_DIR="/opt/update-noti"
SERVICE_NAME="update-noti"

# Optional flags for local/non-root installs
PREFIX=""
NO_SYSTEMD=0

SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
AUTO_UPDATE_PACKAGES="${AUTO_UPDATE_PACKAGES:-}"
SKIP_CONFIG_PROMPT=false

# Preserve original args for fallback parsing after shifting
ORIGINAL_ARGS=("$@")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook) SLACK_WEBHOOK_URL="$2"; shift 2 ;;
    --webhook=*) SLACK_WEBHOOK_URL="${1#*=}"; shift ;;
    --packages) AUTO_UPDATE_PACKAGES="$2"; shift 2 ;;
    --packages=*) AUTO_UPDATE_PACKAGES="${1#*=}"; shift ;;
    --skip-config) SKIP_CONFIG_PROMPT=true; shift ;;
  --prefix) PREFIX="$2"; shift 2 ;;
  --prefix=*) PREFIX="${1#*=}"; shift ;;
  --no-systemd) NO_SYSTEMD=1; shift ;;
    --help|-h)
      cat <<USAGE
Package Updates Notifier Installer (Go)

Usage: $0 [OPTIONS]

Options:
  --webhook=URL        Set Slack webhook URL automatically
  --packages=LIST      Comma-separated list of packages to auto-update
  --skip-config        Skip configuration prompts (use defaults)
  --help, -h           Show this help message

Environment Variables:
  SLACK_WEBHOOK_URL    Slack webhook URL
  AUTO_UPDATE_PACKAGES Comma-separated package list
  
Advanced:
  --prefix=DIR         Install under DIR (non-root allowed; skips systemd/cron)
  --no-systemd         Skip installing systemd units (useful with --prefix)
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Fallback: if --webhook appears in original args and wasn't captured, extract it
if [[ -z "$SLACK_WEBHOOK_URL" && ${#ORIGINAL_ARGS[@]} -gt 0 ]]; then
  for ((i=0; i<${#ORIGINAL_ARGS[@]}; i++)); do
    arg="${ORIGINAL_ARGS[$i]}"
    case "$arg" in
      --webhook=*)
        SLACK_WEBHOOK_URL="${arg#*=}"
        ;;
      --webhook)
        if (( i + 1 < ${#ORIGINAL_ARGS[@]} )); then
          SLACK_WEBHOOK_URL="${ORIGINAL_ARGS[$((i+1))]}"
        fi
        ;;
    esac
    [[ -n "$SLACK_WEBHOOK_URL" ]] && break
  done
fi

# If a webhook was provided via flag/env and is not a placeholder, skip interactive prompt
if [[ -n "$SLACK_WEBHOOK_URL" && "$SLACK_WEBHOOK_URL" != *"YOUR/WEBHOOK/URL"* ]]; then
  SKIP_CONFIG_PROMPT=true
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

if [[ -n "$PREFIX" ]]; then
  INSTALL_DIR="$PREFIX"
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  if [[ -n "$PREFIX" ]]; then
    warning "Non-root install under PREFIX=$PREFIX; skipping systemd and cron."
    NO_SYSTEMD=1
    SKIP_CRON=1
  else
    error "Please run as root (or use --prefix to install in a user directory)"
    exit 1
  fi
fi

command -v curl >/dev/null 2>&1 || { error "curl is required"; exit 1; }

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ASSET="${BIN_NAME}_linux_amd64" ;;
  aarch64|arm64) ASSET="${BIN_NAME}_linux_arm64" ;;
  *) error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TMP_DIR=$(mktemp -d -t update-noti-XXXXXX)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

download_binary() {
  local url="https://github.com/${REPO}/releases/latest/download/${ASSET}"
  local out="$TMP_DIR/${BIN_NAME}"
  log "Downloading binary: $url"
  if ! curl -fsSL -o "$out" -L "$url"; then
    error "Failed to download release asset"
    return 1
  fi
  # Try to verify checksum if checksums.txt is available
  local csum_url="https://github.com/${REPO}/releases/latest/download/checksums.txt"
  local csum_file="$TMP_DIR/checksums.txt"
  if curl -fsSL -o "$csum_file" -L "$csum_url"; then
    if command -v sha256sum >/dev/null 2>&1; then
      local expected
      expected=$(grep "${ASSET}$" "$csum_file" | awk '{print $1}')
      if [[ -n "$expected" ]]; then
        local actual
        actual=$(sha256sum "$out" | awk '{print $1}')
        if [[ "$expected" != "$actual" ]]; then
          error "Checksum verification failed for ${ASSET}"
          return 1
        fi
      fi
    fi
  fi
  chmod 0755 "$out"
  # quick sanity check
  if ! "$out" --version >/dev/null 2>&1; then
    error "Downloaded binary failed to execute"
    return 1
  fi
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "$out" "$INSTALL_DIR/$BIN_NAME"
  success "Installed $BIN_NAME to $INSTALL_DIR"
}

create_config() {
  log "Writing configuration..."
  local pkjson
  if [[ -n "$AUTO_UPDATE_PACKAGES" ]]; then
    pkjson=$(printf '%s' "$AUTO_UPDATE_PACKAGES" | sed 's/[[:space:]]*,[[:space:]]*/", "/g; s/^/"/; s/$/"/')
  else
    pkjson='"tailscale"'
  fi
  local webhook="$SLACK_WEBHOOK_URL"
  if [[ -z "$webhook" ]]; then
    webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  fi
  cat > "$INSTALL_DIR/config.json" <<JSON
{
  "auto_update": [${pkjson}],
  "slack_webhook": "${webhook}",
  "telemetry": { "log_level": "INFO", "log_file": "" }
}
JSON
  chmod 0600 "$INSTALL_DIR/config.json"
  success "Configuration: $INSTALL_DIR/config.json"

  # If webhook was provided, ensure it is written (override placeholder)
  if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    sed -i "s|\"slack_webhook\": \".*\"|\"slack_webhook\": \"$SLACK_WEBHOOK_URL\"|" "$INSTALL_DIR/config.json"
  fi

  # Only prompt if not skipping and the config still has the placeholder URL
  if [[ "$SKIP_CONFIG_PROMPT" = false ]]; then
    if grep -q '"slack_webhook": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"' "$INSTALL_DIR/config.json"; then
      echo -e "${YELLOW}No webhook provided. Enter one now (or leave blank to skip):${NC}"
      read -r input
      if [[ -n "$input" && "$input" == https://hooks.slack.com/services/* ]]; then
        sed -i "s|\"slack_webhook\": \".*\"|\"slack_webhook\": \"$input\"|" "$INSTALL_DIR/config.json"
        success "Webhook saved"
      else
        warning "Webhook unchanged"
      fi
    fi
  fi
}

create_wrapper() {
  log "Creating update wrapper (update.sh)"
  cat > "$INSTALL_DIR/update.sh" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Attempt to self-update to latest release
# Allow disabling via env
if [[ "${UPDATE_NOTI_SKIP_UPDATE:-0}" == "1" ]]; then
  exec "$SCRIPT_DIR/update-noti" "$@"
fi
ASSET="update-noti_linux_amd64"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ASSET="update-noti_linux_amd64" ;;
  aarch64|arm64) ASSET="update-noti_linux_arm64" ;;
esac
# Rate-limit self-update to once per 24h
STATE_DIR="$SCRIPT_DIR/.state"
STAMP="$STATE_DIR/last_update_check"
mkdir -p "$STATE_DIR"
now=$(date +%s)
last=0
if [[ -f "$STAMP" ]]; then last=$(cat "$STAMP" 2>/dev/null || echo 0); fi
if (( now - last > 86400 )); then
  TMP=$(mktemp)
  if curl -fsSL -o "$TMP" -L "https://github.com/raf181/Package-Updates-Noty/releases/latest/download/${ASSET}"; then
    # optional checksum verification
    CSUM_TMP=$(mktemp)
    if curl -fsSL -o "$CSUM_TMP" -L "https://github.com/raf181/Package-Updates-Noty/releases/latest/download/checksums.txt" 2>/dev/null; then
      if command -v sha256sum >/dev/null 2>&1; then
        exp=$(grep "${ASSET}$" "$CSUM_TMP" | awk '{print $1}')
        if [[ -n "$exp" ]]; then
          act=$(sha256sum "$TMP" | awk '{print $1}')
          if [[ "$exp" != "$act" ]]; then
            echo "⚠️ Skipping update: checksum mismatch"
            rm -f "$TMP" "$CSUM_TMP"
            echo "$now" > "$STAMP"
            exec "$SCRIPT_DIR/update-noti" "$@"
          fi
        fi
      fi
    fi
    chmod 0755 "$TMP"
    if "$TMP" --version >/dev/null 2>&1; then
      cp "$TMP" "$SCRIPT_DIR/update-noti"
      echo "✅ Binary updated"
    fi
    rm -f "$TMP" "$CSUM_TMP"
  fi
  echo "$now" > "$STAMP"
fi

exec "$SCRIPT_DIR/update-noti" "$@"
WRAP
  chmod 0755 "$INSTALL_DIR/update.sh"
}

setup_systemd() {
  log "Configuring systemd service and timer"
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=Package Updates Notifier (Go)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/update.sh
Environment=UPDATE_NOTI_SKIP_UPDATE=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

  cat > "/etc/systemd/system/${SERVICE_NAME}.timer" <<UNIT
[Unit]
Description=Run Package Updates Notifier daily
Requires=${SERVICE_NAME}.service

[Timer]
OnCalendar=01:00
OnBootSec=5min
Persistent=true

[Install]
WantedBy=timers.target
UNIT

  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.timer"
  success "Systemd timer enabled"
}

setup_cron() {
  log "Configuring cron fallback"
  local line="0 1 * * * root cd $INSTALL_DIR && ./update.sh >/dev/null 2>&1"
  if ! grep -Fxq "$line" /etc/crontab; then
    echo "$line" >> /etc/crontab
    success "Cron fallback added"
  else
    log "Cron fallback already present"
  fi
}

send_install_complete() {
  log "Sending install-complete message"
  "$INSTALL_DIR/$BIN_NAME" --install-complete --config="$INSTALL_DIR/config.json" || true
}

main() {
  download_binary
  create_config
  create_wrapper
  if [[ "$NO_SYSTEMD" -ne 1 ]] && command -v systemctl >/dev/null 2>&1; then
    setup_systemd
  else
    warning "Skipping systemd setup (either --no-systemd or systemd not available)"
  fi
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    setup_cron
  else
    warning "Skipping cron fallback (non-root)"
  fi
  send_install_complete
  echo
  success "Installation complete"
  echo -e "${BLUE}Install dir:${NC} $INSTALL_DIR"
  echo -e "${BLUE}Config:${NC} $INSTALL_DIR/config.json"
  echo -e "${BLUE}Wrapper:${NC} $INSTALL_DIR/update.sh"
}

main "$@"