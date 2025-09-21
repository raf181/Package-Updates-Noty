# Contributing

Thanks for your interest in contributing!

## Development setup (Go)

- Go 1.22+
- Build locally:
	- `go build -o update-noti ./cmd/update-noti`
	- or `make build` (if you prefer Makefile targets)
- Run locally:
	- `./update-noti --version`
	- `./update-noti --install-complete --config=./config.example.json`

## Pull requests

- Keep changes focused and add a clear description.
- When changing behavior, update docs accordingly.
- Prefer small, incremental PRs over large ones.

## Reporting issues

- Include distro/version, package manager, and relevant logs (`journalctl -u update-noti.service`).
- Describe expected vs. actual behavior.
