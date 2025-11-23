# Home Assistant Kiosk

A simple kiosk setup for displaying Home Assistant dashboards on Linux with Wayland.

## Install

1. create kisok.conf using kisok.conf.example for reference

2. Install with install script
```bash
./install.sh
```

This installs:
- `ha-kiosk` command to `~/.local/bin/`
- Config file to `~/.config/ha-kiosk/kiosk.conf`
- Systemd user service

Edit your config if needed, then start:

```bash
systemctl --user start ha-kiosk.service
```

## Uninstall

Reclone and run uninstall script, or run the one that is copied to your config
```bash
~/.config/ha-kiosk/uninstall.sh
```

## Requirements

- Chromium
- Wayland
- systemd
