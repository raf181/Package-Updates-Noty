# Contributing

Thanks for your interest in contributing!

## Development setup

- Python 3.11+
- Install dev dependency: `pip install -r requirements.txt`
- Build the binary: `python build_binary.py`

## Pull requests

- Keep changes focused and add a clear description.
- When changing behavior, update docs accordingly.
- Prefer small, incremental PRs over large ones.

## Reporting issues

- Include distro/version, package manager, and relevant logs (`journalctl -u update-noti.service`).
- Describe expected vs. actual behavior.
