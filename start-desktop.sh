#!/usr/bin/env bash
set -e

# ----------------------------
# Configuration
# ----------------------------
DISPLAY_NUM=1
VNC_PORT=5900
NOVNC_PORT=6080
RESOLUTION="${DESKTOP_RESOLUTION:-1600x900}x24"

echo "Got resolution $RESOLUTION"

export DISPLAY=:$DISPLAY_NUM
export HOME=/root
export USER=root

# ----------------------------
# Start virtual X server
# ----------------------------
Xvfb :$DISPLAY_NUM -screen 0 $RESOLUTION &
sleep 1

# ----------------------------
# Start D-Bus (needed by XFCE)
# ----------------------------
eval "$(dbus-launch --sh-syntax)"

# ----------------------------
# Start XFCE desktop
# ----------------------------
xfce4-session &

# ----------------------------
# Start VNC server
# ----------------------------
x11vnc \
  -display :$DISPLAY_NUM \
  -rfbport $VNC_PORT \
  -forever \
  -shared \
  -nopw \
  -localhost &

# ----------------------------
# Start noVNC (WebSocket proxy)
# ----------------------------
websockify \
  --web=/usr/share/novnc/ \
  $NOVNC_PORT \
  localhost:$VNC_PORT &

# ----------------------------
# Keep container alive
# ----------------------------
wait
