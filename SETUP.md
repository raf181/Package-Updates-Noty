# Package Updates Noty - Setup Instructions

## Slack Webhook Configuration

Before using this tool, you need to configure a Slack webhook URL for notifications.

### 1. Create a Slack Webhook

1. Go to your Slack workspace
2. Navigate to **Apps** > **Manage** > **Custom Integrations**
3. Click **Incoming Webhooks**
4. Click **Add to Slack**
5. Choose the channel where you want notifications
6. Copy the webhook URL (looks like: `https://hooks.slack.com/services/...`)

### 2. Update the Webhook URL

You need to update the webhook URL in two places:

#### Option A: Update source files (if building locally)
1. Edit `update_noti.py` and replace:
   ```python
   SLACK_WEBHOOK = "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
   ```
2. Edit `install.sh` and replace:
   ```bash
   SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
   ```
3. Run `./build.sh` to rebuild the binary
4. Commit and push changes to create a new release

#### Option B: Update after installation (quick fix)
1. After installation, edit `/opt/update-noti/config.json` and add:
   ```json
   {
     "auto_update": ["tailscale", "netdata"],
     "slack_webhook": "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN"
   }
   ```

## Installation

Once the webhook is configured:

```bash
curl -fsSL https://raw.githubusercontent.com/raf181/Package-Updates-Noty/main/install.sh | sudo bash
```

## Features

- ✅ **Binary Installation**: Downloads standalone binary from GitHub releases
- ✅ **Slack Notifications**: Sends installation completion message with hostname and system info
- ✅ **Auto-Update**: Self-updating from GitHub releases
- ✅ **System Integration**: Systemd timer + cron backup
- ✅ **Package Detection**: Supports apt, dnf, yum, pacman, zypper

## Troubleshooting

### Slack Notifications Not Working

If you see "⚠️ Slack notification failed", check:

1. **Webhook URL**: Make sure it's correct and not expired
2. **Network**: Ensure the system can reach Slack servers
3. **Channel**: Verify the webhook channel exists and the app has permissions

Test your webhook manually:
```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  "YOUR_WEBHOOK_URL"
```
Should return `ok` if working.

## Build System

To build locally:
```bash
./build.sh
```

Creates `dist/update-noti` binary using PyInstaller.