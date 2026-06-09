#!/bin/bash
# Install AnyDesk on Portal (ARM64). Run on device: sudo bash install-anydesk.sh
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
echo "  ID:   $(anydesk --get-id 2>/dev/null || true)"
echo "  PC:   install AnyDesk from https://anydesk.com and enter that ID"
echo "  Set unattended password: AnyDesk → Settings → Security on the Portal"
