#!/bin/bash
# RustDesk — works better than AnyDesk on KDE Wayland (experimental capture).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-rustdesk.sh" >&2
	exit 1
fi

VER="1.3.8"
DEB="rustdesk-${VER}-aarch64.deb"
URL="https://github.com/rustdesk/rustdesk/releases/download/${VER}/${DEB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL="${SCRIPT_DIR}/downloads/${DEB}"
TMP="/tmp/${DEB}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl libxdo3 libxfixes3 libxcb-shape0 libxcb-xfixes0 \
	libpam0g libgstreamer1.0-0 libgstreamer-plugins-base1.0-0

if [[ -f "${LOCAL}" ]]; then
	cp "${LOCAL}" "${TMP}"
else
	curl -fsSL -o "${TMP}" "${URL}"
fi

apt-get install -fy "${TMP}"
systemctl enable --now rustdesk 2>/dev/null || true
rm -f "${TMP}"

echo ""
echo "RustDesk installed."
echo "  Open RustDesk on Portal — note the ID"
echo "  Set password: RustDesk → Settings → Security"
echo "  On PC: install RustDesk from https://rustdesk.com and connect"
echo ""
echo "If black screen on Wayland, try X11: sudo bash enable-portal-x11-for-remote.sh && reboot"
