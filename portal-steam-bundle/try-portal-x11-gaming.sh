#!/bin/bash
# Optional: X11 KDE session for Proton/AnyDesk. REVERT if black screen returns.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash try-portal-x11-gaming.sh" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-aprat}"
[[ -n "$(getent passwd "${STEAM_USER}" 2>/dev/null)" ]] || {
	echo "User ${STEAM_USER} not found. Usage: sudo bash try-portal-x11-gaming.sh" >&2
	exit 1
}

echo "[portal-x11] Installing Xorg + input stack (required for SDDM DisplayServer=x11)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	xorg \
	xserver-xorg \
	xserver-xorg-core \
	xserver-xorg-input-libinput \
	xserver-xorg-video-all \
	xauth \
	x11-xserver-utils

# Remove every Wayland override shipped with the Portal image (SDDM + session env).
rm -f /etc/sddm.conf.d/zz-portal-wayland.conf
rm -f /etc/sddm.conf.d/10-portal-wayland.conf
rm -f /etc/environment.d/50-portal-wayland.conf
rm -f /etc/xdg/plasma-workspace/env/portal-wayland.sh

mkdir -p /etc/sddm.conf.d
rm -f /etc/sddm.conf.d/99-portal-gaming-x11.conf /etc/sddm.conf.d/99-portal-x11-remote.conf

# zz-* wins over 10-portal-wayland if that file is recreated later.
cat >/etc/sddm.conf.d/zz-portal-gaming-x11.conf << EOF
[General]
DisplayServer=x11

[Autologin]
User=${STEAM_USER}
Session=plasma
Relogin=true
EOF

echo ""
echo "[OK] X11 gaming session configured for ${STEAM_USER}"
echo ""
echo "Removed Wayland locks: 10-portal-wayland.conf, 50-portal-wayland.conf, portal-wayland.sh"
echo "SDDM config: /etc/sddm.conf.d/zz-portal-gaming-x11.conf"
echo ""
echo "WARNING: X11 caused black-screen KDE on some Portal builds."
echo "If desktop breaks after reboot:"
echo "  sudo portal-restore-wayland && sudo reboot"
echo ""
echo "Apply now (logs you out):  sudo systemctl restart sddm"
echo "Or reboot:  sudo reboot"
echo "After new session:  echo \$XDG_SESSION_TYPE   # should print x11"
