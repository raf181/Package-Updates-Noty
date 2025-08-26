# Uninstall

The following steps remove the service, timers, and files created by the installer.

```bash
sudo systemctl disable --now update-noti.timer || true
sudo rm -f /etc/systemd/system/update-noti.service /etc/systemd/system/update-noti.timer
sudo sed -i '\|/opt/update-noti && ./update.sh|d' /etc/crontab
sudo rm -rf /opt/update-noti
sudo systemctl daemon-reload
```

If you installed custom files or modified the config path, adjust accordingly.
