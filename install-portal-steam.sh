#!/usr/bin/env bash
# Install Portal Steam on the device. Copy the portable bundle anywhere — path does not matter.
#
# On PC (CachyOS):  bash pack-portal-steam.sh
# Copy to device:   scp portal-steam-bundle.tar.gz odin2@portal:~/
# On device:         tar xzf portal-steam-bundle.tar.gz
#                    cd portal-steam-bundle && sudo bash install-portal-steam.sh
# Then as odin2:     portal-install-steam && portal-steam --gamepadui

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

portal_steam_find_source() {
	local d
	for d in \
		"${SCRIPT_DIR}" \
		"${SCRIPT_DIR}/os/portal-steam" \
		"${SCRIPT_DIR}/portal-steam"; do
		if [[ -f "${d}/portal-steam" && -d "${d}/share" ]]; then
			echo "${d}"
			return 0
		fi
	done
	return 1
}

SRC="$(portal_steam_find_source)" || {
	echo "ERROR: portal-steam files not found next to this script." >&2
	echo "  Expected: portal-steam + share/ in the same folder, or os/portal-steam/ under repo root." >&2
	echo "  On PC run: bash pack-portal-steam.sh  then copy portal-steam-bundle.tar.gz to the device." >&2
	exit 1
}

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-portal-steam.sh" >&2
	exit 1
fi

echo "[portal-steam] Source: ${SRC}"
echo "[portal-steam] Installing apt dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Noble 24.04 renamed many libs (*t64). Try each alias until one installs.
portal_steam_apt_install_one() {
	local pkg ok=0 name
	for name in "$@"; do
		if apt-cache show "${name}" >/dev/null 2>&1; then
			apt-get install -y --no-install-recommends "${name}" && ok=1 && break
		fi
	done
	[[ "${ok}" -eq 1 ]]
}

portal_steam_apt_install() {
	local -a core=(
		gamescope jq unzip wget curl ca-certificates libnss3 libsdl2-2.0-0
		vulkan-tools mesa-vulkan-drivers libxtst6 libxi6 libgbm1 file libvulkan1
	)
	local -a optional_groups=(
		"mangohud"
		"squashfuse"
		"libfuse2"
		"libvpx9"
		"libminizip1 libminizip1t64"
		"libgtk-3-0 libgtk-3-0t64"
		"libdbus-1-3 libdbus-1-3t64"
		"libasound2 libasound2t64"
		"libpulse0 libpulse0t64"
		"libudev1 libudev1t64"
		"libusb-1.0-0"
		"libegl1"
		"libdrm2"
		"libwayland-client0"
		"libva2"
	)

	apt-get install -y --no-install-recommends "${core[@]}"

	local group
	for group in "${optional_groups[@]}"; do
		# shellcheck disable=SC2086
		portal_steam_apt_install_one ${group} || \
			echo "[portal-steam] optional not installed (OK): ${group%% *}"
	done
}
portal_steam_apt_install

echo "[portal-steam] Installing to /usr/local/bin and /usr/share/portal-steam ..."
install -d /usr/share/portal-steam /usr/local/bin /usr/share/applications
cp -a "${SRC}/share/." /usr/share/portal-steam/
install -m755 "${SRC}/portal-steam" /usr/local/bin/portal-steam
install -m755 "${SRC}/install-steam.sh" /usr/local/bin/portal-install-steam
install -m755 "${SRC}/portal-steam-common.sh" /usr/local/bin/portal-steam-common.sh
install -m755 "${SRC}/install-fex.sh" /usr/local/bin/portal-install-fex
if [[ -f "${SRC}/setup-games.sh" ]]; then
	install -m755 "${SRC}/setup-games.sh" /usr/local/bin/portal-setup-games
else
	echo "[portal-steam] WARN: setup-games.sh missing from bundle — repack with pack-portal-steam.ps1"
fi
sed -i 's|SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE\[0\]}")" && pwd)"|SCRIPT_DIR="/usr/local/bin"|' \
	/usr/local/bin/portal-steam /usr/local/bin/portal-install-steam
install -m644 "${SRC}/share/applications/portal-steam.desktop" /usr/share/applications/

echo ""
echo "Installed. You can delete this folder on the device — commands are in /usr/local/bin."
echo "  portal-install-steam    # as odin2 — downloads ARM64 public-beta client"
echo "  portal-steam --gamepadui"
echo "  sudo portal-install-fex && portal-setup-games   # required for Proton games"
