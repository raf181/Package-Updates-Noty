# Go Migration Overview

This project has been ported from Python to Go to mirror the architecture of `SSH-Noty`.

- Go module at `go.mod`
- Entry point: `cmd/update-noti/main.go`
- Config: `config.example.json` (placed at `/opt/update-noti/config.json` when installed)
- Packages:
  - `internal/config`: JSON config loader
  - `internal/logging`: JSON structured logs (slog)
  - `internal/notify`: Slack webhook sender
  - `internal/system`: System info collection (hostname, IP, OS, uptime, time)
  - `internal/pm`: Package manager detection and operations (upgradable list, auto-update)

Feature parity:

- Detects package manager (apt, dnf, yum, pacman, zypper)
- Lists upgradable packages
- Auto-updates only packages listed in `auto_update`
- Sends a formatted Slack message mirroring the Python output
- `--install-complete` flag sends the installation summary

Next steps:

- Provide an installer script analogous to `SSH-Noty` that places binary in `/opt/update-noti`, writes config, and sets up systemd timer
- Remove Python build artifacts and update README to reflect Go implementation
- Add CI to build release binaries for linux/amd64 and linux/arm64
