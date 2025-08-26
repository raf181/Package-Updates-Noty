# Installation guide

The easiest way to install is via the one-line installer. You can provide your Slack webhook up front so you’ll receive notifications immediately.

## One-line install

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

Optional: predefine the list of packages that should auto-update (comma-separated):

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
AUTO_UPDATE_PACKAGES="tailscale,netdata,nginx" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

## Installer flags

```text
--webhook=URL        Set Slack webhook URL automatically
--packages=LIST      Comma-separated list to auto-update (e.g. nginx,docker.io,tailscale)
--skip-config        Skip interactive prompts (useful for automation)
```

Environment variables:

- SLACK_WEBHOOK_URL: Slack webhook URL
- AUTO_UPDATE_PACKAGES: Comma-separated package list

Examples:

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash -s -- \
  --webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  --packages="tailscale,netdata"
```

## What the installer sets up

- Installation directory: /opt/update-noti
- Config file: /opt/update-noti/config.json
- Update wrapper: /opt/update-noti/update.sh (auto self-updates the binary then runs it)
- systemd service: /etc/systemd/system/update-noti.service
- systemd timer: /etc/systemd/system/update-noti.timer (daily at 01:00; persistent)
- Cron fallback: an entry in /etc/crontab

If a Slack webhook is configured, you’ll receive an “Installation completed” message.
