#!/usr/bin/env bash
# Retrofit Steam layer onto an existing Portal Armbian image (no full reflash).
# Run on the device (or chroot) as root. Then as odin2: portal-install-steam

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/os/portal-steam"

if [[ ! -f "${SRC}/portal-steam" ]]; then
	echo "ERROR: ${SRC}/portal-steam not found. Run from armbian_steamos repo root." >&2
	exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-portal-steam.sh" >&2
	exit 1
fi

echo "[portal-steam] Installing apt dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	gamescope jq mangohud squashfuse-tools libfuse2 unzip \
	wget curl ca-certificates libnss3 libsdl2-2.0-0 \
	vulkan-tools libxtst6 libxi6 libgbm1 file

echo "[portal-steam] Installing scripts to /usr/local/bin and /usr/share/portal-steam ..."
install -d /usr/share/portal-steam /usr/local/bin /usr/share/applications
cp -a "${SRC}/share/." /usr/share/portal-steam/
install -m755 "${SRC}/portal-steam" /usr/local/bin/portal-steam
install -m755 "${SRC}/install-steam.sh" /usr/local/bin/portal-install-steam
install -m755 "${SRC}/portal-steam-common.sh" /usr/local/bin/portal-steam-common.sh
install -m755 "${SRC}/install-fex.sh" /usr/local/bin/portal-install-fex
sed -i 's|SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE\[0\]}")" && pwd)"|SCRIPT_DIR="/usr/local/bin"|' \
	/usr/local/bin/portal-steam /usr/local/bin/portal-install-steam
install -m644 "${SRC}/share/applications/portal-steam.desktop" /usr/share/applications/

echo ""
echo "Done. Steam = native aarch64 (portal-steam). FEX optional for x86 games later."
echo "  portal-install-steam    # as odin2, needs network"
echo "  portal-steam --gamepadui"
echo "  sudo portal-install-fex # optional, when you need x86 Proton games"
