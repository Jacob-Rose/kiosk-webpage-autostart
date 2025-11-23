#!/bin/bash
# Home Assistant Kiosk Installer

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ha-kiosk"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="ha-kiosk.service"
COMMAND_NAME="ha-kiosk"

echo "Installing Home Assistant Kiosk..."

# Check if already running (for reinstall)
WAS_RUNNING=false
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "Stopping existing service..."
    systemctl --user stop "$SERVICE_NAME"
    WAS_RUNNING=true
fi

# Check dependencies
echo "Checking dependencies..."
if ! command -v chromium &> /dev/null; then
    echo "Error: chromium is required but not installed."
    exit 1
fi
echo "chromium found."

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$SERVICE_DIR"

# Install config file
if [ ! -f "$CONFIG_DIR/kiosk.conf" ]; then
    if [ -f "$SCRIPT_DIR/kiosk.conf" ]; then
        echo "Installing config from repo..."
        cp "$SCRIPT_DIR/kiosk.conf" "$CONFIG_DIR/kiosk.conf"
    else
        echo "Creating default config..."
        cp "$SCRIPT_DIR/kiosk.conf.example" "$CONFIG_DIR/kiosk.conf"
        echo ""
        echo "IMPORTANT: Edit $CONFIG_DIR/kiosk.conf with your Home Assistant URL"
        echo ""
    fi
else
    echo "Config already exists, keeping existing."
fi

# Install the main script (modified to use config dir)
echo "Installing $COMMAND_NAME to $INSTALL_DIR..."
cat > "$INSTALL_DIR/$COMMAND_NAME" << 'SCRIPT'
#!/bin/bash
# Home Assistant Kiosk Script

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ha-kiosk"
source "$CONFIG_DIR/kiosk.conf"

# Wait for the display to be ready
sleep 5

# Launch Chromium in kiosk mode
chromium \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --no-first-run \
    --start-fullscreen \
    --enable-features=UseOzonePlatform \
    --ozone-platform=wayland \
    "$HA_URL"
SCRIPT
chmod +x "$INSTALL_DIR/$COMMAND_NAME"

# Generate and install service file
echo "Installing systemd service..."
cat > "$SERVICE_DIR/$SERVICE_NAME" << EOF
[Unit]
Description=Home Assistant Kiosk Browser
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$COMMAND_NAME
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-1

[Install]
WantedBy=graphical-session.target
EOF

# Create uninstall script
echo "Creating uninstall script..."
cat > "$CONFIG_DIR/uninstall.sh" << EOF
#!/bin/bash
echo "Uninstalling Home Assistant Kiosk..."

# Stop and disable service
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl --user stop "$SERVICE_NAME"
fi
if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl --user disable "$SERVICE_NAME"
fi

# Remove files
rm -f "$SERVICE_DIR/$SERVICE_NAME"
rm -f "$INSTALL_DIR/$COMMAND_NAME"
rm -rf "$CONFIG_DIR"

systemctl --user daemon-reload

echo "Uninstall complete."
EOF
chmod +x "$CONFIG_DIR/uninstall.sh"

# Reload systemd and enable service
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"

echo ""
echo "Installed successfully!"
echo "  Command:  $INSTALL_DIR/$COMMAND_NAME"
echo "  Config:   $CONFIG_DIR/kiosk.conf"
echo "  Service:  $SERVICE_DIR/$SERVICE_NAME"
echo ""

# Restart if it was running before
if [ "$WAS_RUNNING" = true ]; then
    echo "Restarting service..."
    systemctl --user start "$SERVICE_NAME"
    echo "Service restarted."
else
    echo "Start with:    systemctl --user start $SERVICE_NAME"
fi

echo "Check status:  systemctl --user status $SERVICE_NAME"
echo ""
echo "To uninstall:  $CONFIG_DIR/uninstall.sh"
