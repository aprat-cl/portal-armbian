#!/bin/bash
# Switch SDDM to X11 so AnyDesk (and most VNC) can capture the desktop.
# Wayland = "display server not supported" on AnyDesk incoming sessions.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash enable-portal-x11-for-remote.sh" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-odin2}"
mkdir -p /etc/sddm.conf.d

cat >/etc/sddm.conf.d/99-portal-x11-remote.conf <<EOF
[General]
DisplayServer=x11

[Autologin]
User=${STEAM_USER}
Session=plasma
EOF

# Disable Wayland override if present (Armbian image ships this)
rm -f /etc/sddm.conf.d/zz-portal-wayland.conf
rm -f /etc/environment.d/50-portal-wayland.conf
rm -f /etc/xdg/plasma-workspace/env/portal-wayland.sh

echo "[OK] SDDM set to X11 for user ${STEAM_USER}"
echo "Reboot now:  sudo reboot"
echo "After reboot, AnyDesk should connect. Check: echo \$XDG_SESSION_TYPE  →  x11"
