#!/bin/bash
# Install AnyDesk on Portal (ARM64). Requires KDE **X11** session (not Wayland).
# Run on device: sudo bash install-anydesk.sh
set -euo pipefail

DEB_URL="https://deb.anydesk.com/pool/main/a/anydesk/anydesk_8.0.2_arm64.deb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DEB="${SCRIPT_DIR}/downloads/anydesk_8.0.2_arm64.deb"
TMP_DEB="/tmp/anydesk_8.0.2_arm64.deb"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-anydesk.sh" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl

if [[ -f "${LOCAL_DEB}" ]]; then
	echo "[anydesk] Installing from ${LOCAL_DEB}"
	cp "${LOCAL_DEB}" "${TMP_DEB}"
else
	echo "[anydesk] Downloading ARM64 package..."
	curl -fsSL -o "${TMP_DEB}" "${DEB_URL}"
fi

apt-get install -y "${TMP_DEB}"
systemctl enable --now anydesk
rm -f "${TMP_DEB}"

echo ""
echo "AnyDesk installed."
echo ""
echo "IMPORTANT: AnyDesk incoming remote control needs X11, NOT Wayland."
echo "  On Portal run once:  sudo bash enable-portal-x11-for-remote.sh"
echo "  Then reboot and log in (SDDM uses X11 automatically)."
echo ""
echo "  ID:   $(anydesk --get-id 2>/dev/null || true)"
echo "  Or use RustDesk (better Wayland): sudo bash install-rustdesk.sh"
