# Update Notification System

A standalone tool that checks for system package updates and sends notifications to Slack.

## ⚡ Quick Start

```bash
# Basic installation
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash

# With automatic Slack webhook setup
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo -E bash

# Full automated setup with custom packages
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | \
sudo bash -s -- \
  --webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  --packages="nginx,docker.io,tailscale" \
  --skip-config
```

## 🚀 One-Line Install

### Basic Installation

Install and configure everything automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

### 🔧 Install with Automatic Slack Configuration

#### Option 1: Command-line arguments

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash -s -- --webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

#### Option 2: Environment variables

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo -E bash
```

#### Option 3: Full automated setup

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | \
sudo bash -s -- \
  --webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  --packages="nginx,docker.io,tailscale" \
  --skip-config
```

### 📋 Installation Options

| Option | Description | Example |
|--------|-------------|----------|
| `--webhook=URL` | Set Slack webhook automatically | `--webhook="https://hooks.slack.com/..."` |
| `--packages=LIST` | Comma-separated auto-update packages | `--packages="nginx,docker,tailscale"` |
| `--skip-config` | Skip interactive prompts | `--skip-config` |
| `--help` | Show help information | `--help` |

That's it! The system will:
- ✅ Install the binary to `/opt/update-noti/`
- ✅ Set up daily execution at 01:00 (systemd + cron backup)
- ✅ Enable auto-updates on each run
- ✅ Create default configuration
- ✅ Run on boot (5 minutes after boot) if a scheduled run was missed

## 📁 Files

After installation you'll have:
- `/opt/update-noti/update-noti` - Standalone binary (8.6MB)
- `/opt/update-noti/config.json` - Configuration file
- `/opt/update-noti/update.sh` - Self-updater wrapper

## 🔧 Configuration

### Automatic Configuration (Recommended)
Use the enhanced installer for zero-touch setup:

```bash
# Fully automated installation
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | \
sudo bash -s -- \
  --webhook="YOUR_SLACK_WEBHOOK_URL" \
  --packages="nginx,docker.io,tailscale" \
  --skip-config
```

### Manual Configuration
Edit `/opt/update-noti/config.json` to customize auto-update packages and set your Slack webhook:

```json
{
  "auto_update": [
    "tailscale",
    "netdata",
    "nginx",
    "docker.io"
  ],
  "slack_webhook": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}
```

⚠️ **Security Note**: You **must** configure your own Slack webhook URL in `config.json`. The application will not work without proper webhook configuration.

## 📦 Supported Package Managers

- **APT** (Debian, Ubuntu)
- **DNF** (Fedora, RHEL 8+)
- **YUM** (RHEL, CentOS 7)
- **Pacman** (Arch Linux)
- **Zypper** (openSUSE)

## 💬 Slack Integration

The tool sends beautifully formatted notifications including:
- System info (hostname, IP, OS, uptime)
- Available package updates
- Auto-updated packages
- Visual formatting with emojis and sections

## ⏰ Scheduling

Automatically configured:
- **Systemd Timer**: Daily at 01:00 + 5min after boot if missed
- **Cron Fallback**: Daily at 01:00

## 🔄 Self-Updating

The system automatically checks for and downloads new versions on each run.

## 🧪 Manual Testing

```bash
cd /opt/update-noti && ./update.sh
```

## 📊 Status Check

```bash
systemctl status update-noti.timer
crontab -l | grep update-noti
```

## 🗑️ Uninstall

```bash
sudo systemctl disable --now update-noti.timer
sudo rm -rf /opt/update-noti /etc/systemd/system/update-noti.*
sudo crontab -l | grep -v update-noti | sudo crontab -
sudo systemctl daemon-reload
```

## � Troubleshooting

### Common Installation Issues

#### 1. Directory Access Errors
**Symptom**: `getcwd: cannot access parent directories` or empty installation directory

**Solution**: The installer now uses secure temporary directories and comprehensive cleanup:
- The script automatically creates `/tmp/update-noti-install-$$` for safe operations
- All operations are performed in temp directories to avoid path conflicts
- Automatic cleanup on success, failure, or interruption

#### 2. Binary Download Failures
**Symptom**: Binary download fails or invalid binary downloaded

**Causes & Solutions**:
- **No GitHub release**: Wait for binary release or fallback to Python script works automatically
- **Network issues**: Installer retries with both `curl` and `wget` with timeouts
- **Invalid binary**: Installer verifies downloaded files using `file` command

**Verification**: The installer checks if downloaded files are valid ELF executables:
```bash
file update-noti | grep -q "ELF\|executable"
```

#### 3. Python Script Fallback Issues
**Symptom**: Python script fails to download or execute

**Solutions**:
- Ensure Python 3 is installed: `sudo apt install python3` (or equivalent)
- Check internet connectivity to GitHub
- Verify raw.githubusercontent.com is accessible

#### 4. Permission Errors
**Symptom**: Installation fails with permission denied

**Solutions**:
```bash
# Run with sudo
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash

# Or download and run locally
wget https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh
sudo bash install.sh
```

#### 5. Systemd Service Issues
**Symptom**: Timer not starting or service fails

**Diagnostics**:
```bash
# Check service status
systemctl status update-noti.service
systemctl status update-noti.timer

# View logs
journalctl -u update-noti.service -f
journalctl -u update-noti.timer -f

# Test manual execution
cd /opt/update-noti && sudo ./update.sh
```

**Solutions**:
- Verify `/opt/update-noti/update-noti` exists and is executable
- Check if `systemctl` is available and working
- Ensure systemd daemon is reloaded: `sudo systemctl daemon-reload`

#### 6. Slack Notifications Not Working
**Symptom**: No Slack messages or webhook errors

**Solutions**:
1. **Configure webhook URL**: Edit `/opt/update-noti/config.json`:
   ```json
   {
     "slack_webhook": "https://hooks.slack.com/services/YOUR_ACTUAL_WEBHOOK_URL"
   }
   ```

2. **Test webhook manually**:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test message"}' \
     "YOUR_WEBHOOK_URL"
   ```
   Should return `ok` if working.

3. **Check network connectivity**:
   ```bash
   curl -I https://hooks.slack.com
   ```

#### 7. Auto-Update Not Working
**Symptom**: Binary doesn't update automatically

**Diagnostics**:
```bash
# Check for updates manually
cd /opt/update-noti
curl -I https://github.com/raf181/Package-Updates-Noty/releases/latest/download/update-noti
```

**Solutions**:
- Ensure GitHub releases contain the binary (`update-noti`)
- Verify internet connectivity during scheduled runs
- Check if the binary URL returns a valid ELF file

### Testing Installation

#### Complete Installation Test
```bash
# 1. Test binary directly
cd /opt/update-noti
./update-noti --help || echo "Exit code: $?"

# 2. Test wrapper script
./update.sh

# 3. Test systemd service
sudo systemctl start update-noti.service
sudo systemctl status update-noti.service

# 4. Check timer
sudo systemctl status update-noti.timer
sudo systemctl list-timers | grep update-noti

# 5. Test configuration
cat config.json | python3 -m json.tool
```

#### Emergency Reset
If installation is completely broken:
```bash
# Complete cleanup
sudo systemctl stop update-noti.timer update-noti.service 2>/dev/null || true
sudo systemctl disable update-noti.timer update-noti.service 2>/dev/null || true
sudo rm -rf /opt/update-noti
sudo rm -f /etc/systemd/system/update-noti.*
sudo systemctl daemon-reload
crontab -l | grep -v update-noti | crontab - 2>/dev/null || true

# Fresh reinstall
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

### Advanced Debugging

#### Trace Installation Process
```bash
# Download and run with debugging
wget https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh
bash -x install.sh 2>&1 | tee install-debug.log
```

#### Check File Integrity
```bash
# Verify binary is working
cd /opt/update-noti
file update-noti
ls -la update-noti
ldd update-noti  # Check dependencies
```

#### Network Connectivity Testing
```bash
# Test GitHub connectivity
curl -v https://api.github.com/repos/raf181/Package-Updates-Noty/releases/latest
curl -I https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh
```

## �📊 Message Format

The Slack messages include:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SYSTEM UPDATE CHECK 🔍
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Time: 2025-08-21 22:09:15
🖥️ Host: server01 (192.168.1.100)
💻 OS: Linux 5.15.0
⏰ Uptime: 72h
📦 Package Manager: apt
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 AVAILABLE UPDATES (3):
  • curl
  • vim
  • nginx
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ STATUS: All packages are up to date! 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```