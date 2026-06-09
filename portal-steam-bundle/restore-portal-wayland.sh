#!/bin/bash
# Revert SDDM to Wayland (fixes black-screen KDE if X11 session breaks video).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash restore-portal-wayland.sh" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-aprat}"
mkdir -p /etc/sddm.conf.d

rm -f /etc/sddm.conf.d/99-portal-gaming-x11.conf
rm -f /etc/sddm.conf.d/99-portal-x11-remote.conf

cat >/etc/sddm.conf.d/zz-portal-wayland.conf << EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
User=${STEAM_USER}
Session=plasma
Relogin=true

[Wayland]
Compositor=kwin_wayland
EOF

echo "[OK] SDDM restored to Wayland for ${STEAM_USER}"
echo "Reboot: sudo reboot"
echo "Then: echo \$XDG_SESSION_TYPE  →  wayland"
