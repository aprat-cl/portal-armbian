#!/bin/bash
# Optional: try X11 SDDM for Proton/AnyDesk. REVERT if black screen returns.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash try-portal-x11-gaming.sh" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-aprat}"
mkdir -p /etc/sddm.conf.d

rm -f /etc/sddm.conf.d/zz-portal-wayland.conf

cat >/etc/sddm.conf.d/99-portal-gaming-x11.conf << EOF
[General]
DisplayServer=x11

[Autologin]
User=${STEAM_USER}
Session=plasma
Relogin=true
EOF

echo "[OK] SDDM set to X11 for ${STEAM_USER}"
echo ""
echo "WARNING: X11 caused black-screen KDE on some Portal builds."
echo "If desktop breaks after reboot:"
echo "  sudo bash restore-portal-wayland.sh && sudo reboot"
echo ""
echo "Reboot now: sudo reboot"
