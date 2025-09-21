# Package Updates Notifier (update-noti)

Go implementation. This tool checks for OS package updates across popular Linux distributions, optionally auto-updates selected packages, and posts a formatted summary to Slack.

- Single-file Go binary
- Supports apt, dnf, yum, pacman, zypper
- Daily scheduling via systemd timer


## Quick start

Install in one line. Pass your Slack webhook to start receiving notifications immediately.

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash -s -- --webhook="$SLACK_WEBHOOK_URL"
```

Optionally, predefine an auto-update list (comma-separated):

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
AUTO_UPDATE_PACKAGES="tailscale,netdata,nginx" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash -s -- --webhook="$SLACK_WEBHOOK_URL" --packages="$AUTO_UPDATE_PACKAGES"
```

What you get:

- Installed to `/opt/update-noti`
- Config at `/opt/update-noti/config.json`
- Scheduled daily at 01:00 with 5-minute boot delay
- A test “Installation completed” Slack message (if webhook is configured)


## How it works

1) Detects your package manager (apt, dnf, yum, pacman, zypper)
2) Lists all upgradable packages
3) Auto-updates only the packages you explicitly allow in `auto_update`
4) Sends a Slack message with system info, upgradable packages, and which ones were auto-updated


## Configuration

File: `/opt/update-noti/config.json`

```json
{
  "auto_update": ["tailscale", "netdata"],
  "slack_webhook": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}
```

- slack_webhook: Required for Slack notifications. Without it, messages won’t be sent.
- auto_update: Only these packages will be auto-installed when updates are found. All available updates are still listed in Slack.

See more examples and tips in docs/CONFIG.md


## Usage

Run it ad-hoc:

```bash
sudo /opt/update-noti/update-noti
```

Version:

```bash
sudo /opt/update-noti/update-noti --version
```

Special flag used by the installer to emit a “installed” Slack message:

```bash
sudo /opt/update-noti/update-noti --install-complete
```


## Scheduling

The installer configures a systemd service and timer.

- Systemd service: `/etc/systemd/system/update-noti.service`
- Systemd timer: `/etc/systemd/system/update-noti.timer` (runs daily at 01:00, persistent across reboots)

Useful commands:

```bash
sudo systemctl status update-noti.service
sudo systemctl status update-noti.timer
sudo journalctl -u update-noti.service -n 200 --no-pager
```


## Supported environments

- Linux x86_64
- Package managers: apt, dnf, yum, pacman, zypper
- Network access to:
  - Your distro repos (to check/install updates)
  - Slack (to post via incoming webhook)

Root is required to install packages; the installer enforces running as root.


## Install options

The installer accepts flags or environment variables.

Flags:

- `--webhook=URL`      Set Slack webhook URL automatically
- `--packages=LIST`    Comma-separated list to auto-update (e.g. `nginx,docker.io,tailscale`)
- `--skip-config`      Skip interactive prompts (useful for automation)

Environment variables:

- `SLACK_WEBHOOK_URL`  Slack webhook URL
- `AUTO_UPDATE_PACKAGES` Comma-separated package list

Examples:

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash -s -- \
  --webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  --packages="tailscale,netdata"

# or purely via env vars
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
AUTO_UPDATE_PACKAGES="tailscale,netdata" \
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```


## Build from source (Go)

Requirements: Go 1.22+

```bash
make build
./update-noti --version
```


## Security notes

- Store your Slack webhook in `/opt/update-noti/config.json`. Limit file permissions to root if desired:

```bash
sudo chown root:root /opt/update-noti/config.json
sudo chmod 600 /opt/update-noti/config.json
```

- The self-update step downloads the latest release from GitHub over HTTPS and verifies it can run `--help` before replacing the current binary.


## Troubleshooting

Start here: docs/TROUBLESHOOTING.md

Common checks:

- Verify your Slack webhook is correct and reachable from the host
- Run manually and inspect logs:

```bash
sudo /opt/update-noti/update-noti
sudo journalctl -u update-noti.service -n 200 --no-pager
```


## Uninstall

See docs/UNINSTALL.md for a complete teardown. In short:

```bash
sudo systemctl disable --now update-noti.timer || true
sudo rm -f /etc/systemd/system/update-noti.service /etc/systemd/system/update-noti.timer
sudo sed -i '\|/opt/update-noti && ./update.sh|d' /etc/crontab
sudo rm -rf /opt/update-noti
sudo systemctl daemon-reload
```


## Contributing

Bug reports and PRs are welcome. See CONTRIBUTING.md


## License

See LICENSE


---

If this project helps you keep machines up-to-date with fewer surprises, a GitHub star is always appreciated.

