# Configuration

The configuration file lives at:

- /opt/update-noti/config.json

Example:

```json
{
  "auto_update": ["tailscale", "netdata"],
  "slack_webhook": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}
```

Fields:

- slack_webhook (string)
  - Required to send Slack notifications.
  - Must be a Slack Incoming Webhook URL.
- auto_update (array of strings)
  - Only packages listed here will be automatically updated when updates are available.
  - All other available updates will still be listed in Slack but not installed.

Tips:

- You can edit the file safely at any time. A subsequent run will pick up changes.
- To test the webhook, use the interactive prompt from the installer (run it again with `--skip-config` omitted), or trigger a manual run:

```bash
sudo /opt/update-noti/update.sh
```

Security:

```bash
sudo chown root:root /opt/update-noti/config.json
sudo chmod 600 /opt/update-noti/config.json
```
