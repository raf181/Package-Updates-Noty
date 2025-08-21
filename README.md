# Update Notification System

A standalone tool that checks for system package updates and sends notifications to Slack.

## 🚀 One-Line Install

Install and configure everything automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

Or with wget:
```bash
wget -qO- https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

That's it! The system will:
- ✅ Install the binary to `/opt/update-noti/`
- ✅ Set up daily execution at 00:00 (systemd + cron backup)
- ✅ Enable auto-updates on each run
- ✅ Create default configuration
- ✅ Run on boot if midnight execution was missed

## 📁 Files

After installation you'll have:
- `/opt/update-noti/update-noti` - Standalone binary (8.6MB)
- `/opt/update-noti/config.json` - Configuration file
- `/opt/update-noti/update.sh` - Self-updater wrapper

## 🔧 Configuration

Edit `/opt/update-noti/config.json` to customize auto-update packages:

```json
{
  "auto_update": [
    "tailscale",
    "netdata",
    "nginx",
    "docker.io"
  ]
}
```

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
- **Systemd Timer**: Daily at 00:00 + 5min after boot if missed
- **Cron Fallback**: Daily at 00:00

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

## 📊 Message Format

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