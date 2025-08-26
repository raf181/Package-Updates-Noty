# Troubleshooting

A few quick checks can usually resolve most issues.

## Verify the service and timer

```bash
sudo systemctl status update-noti.service
sudo systemctl status update-noti.timer
sudo journalctl -u update-noti.service -n 200 --no-pager
```

## Run manually

```bash
sudo /opt/update-noti/update.sh
```

## Slack messages not appearing

- Ensure `slack_webhook` in /opt/update-noti/config.json is a valid Slack Incoming Webhook URL.
- Confirm the machine has outbound internet access to Slack.
- Look for errors printed by the app when running manually.

## No updates found, but you expect some

- The tool detects updates via your package manager. Try the equivalent command manually:
  - apt: `apt list --upgradable`
  - dnf: `dnf check-update`
  - yum: `yum check-update`
  - pacman: `pacman -Qu`
  - zypper: `zypper list-updates`

## Auto-update didn’t install a package you expected

- Only packages listed in `auto_update` will be installed automatically.
- Verify the exact package name matches what your package manager reports.

## Systemd missing or disabled

- The installer adds a cron fallback in /etc/crontab.
- You can still run the tool manually via `/opt/update-noti/update.sh`.

## Self-update fails

- The wrapper downloads the latest binary and verifies it can run `--help` before replacing.
- If downloads are blocked by a proxy/firewall, disable self-update by running the script directly (`/opt/update-noti/update-noti`).
