#!/usr/bin/env bash
# Install Portal Steam on the device. Copy the portable bundle anywhere — path does not matter.
#
# On PC:  bash pack-portal-steam.sh  OR  powershell -File pack-portal-steam.ps1
#
# On device (first time or after a broken Steam start-over):
#   cd portal-steam-bundle
#   sudo bash install-portal-steam.sh --full
#
# Scripts only (no Steam download):
#   sudo bash install-portal-steam.sh
#
# Env: PORTAL_STEAM_USER=aprat

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_SETUP=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--full | --reinstall) FULL_SETUP=1; shift ;;
		-h | --help)
			cat <<'EOF'
install-portal-steam.sh

  sudo bash install-portal-steam.sh           Install /usr/local/bin tools + apt packages
  sudo bash install-portal-steam.sh --full    Above + full Steam/Proton/FEX reinstall

--full keeps your game installs; re-downloads Steam client, libvpx6, Proton, FEX rootfs.
Set PORTAL_STEAM_USER=aprat if not using sudo from your login user.
EOF
			exit 0
			;;
		*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
	esac
done

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
	exit 1
}

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-portal-steam.sh [--full]" >&2
	exit 1
fi

PORTAL_STEAM_USER="${PORTAL_STEAM_USER:-${SUDO_USER:-}}"
if [[ -z "${PORTAL_STEAM_USER}" || "${PORTAL_STEAM_USER}" == "root" ]]; then
	for u in aprat portal odin2; do
		if getent passwd "${u}" >/dev/null 2>&1; then
			PORTAL_STEAM_USER="${u}"
			break
		fi
	done
fi

echo "[portal-steam] Source: ${SRC}"
echo "[portal-steam] Steam user: ${PORTAL_STEAM_USER:-unknown — set PORTAL_STEAM_USER}"
echo "[portal-steam] Installing apt dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update

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
		evtest joystick dpkg
	)
	local -a optional_groups=(
		"mangohud" "squashfuse" "squashfs-tools" "libfuse2" "libvpx9"
		"libminizip1 libminizip1t64" "libgtk-3-0 libgtk-3-0t64"
		"libdbus-1-3 libdbus-1-3t64" "libasound2 libasound2t64"
		"libpulse0 libpulse0t64" "libudev1 libudev1t64" "libusb-1.0-0"
		"libegl1" "libdrm2" "libwayland-client0" "libva2"
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

portal_steam_install_script() {
	local src_name="$1" dest_name="$2"
	if [[ -f "${SRC}/${src_name}" ]]; then
		install -m755 "${SRC}/${src_name}" "/usr/local/bin/${dest_name}"
	else
		echo "[portal-steam] WARN: missing ${src_name} — repack bundle from latest repo"
	fi
}

echo "[portal-steam] Installing to /usr/local/bin and /usr/share/portal-steam ..."
install -d /usr/share/portal-steam /usr/local/bin /usr/share/applications
cp -a "${SRC}/share/." /usr/share/portal-steam/

portal_steam_install_script portal-steam portal-steam
portal_steam_install_script install-steam.sh portal-install-steam
portal_steam_install_script portal-steam-common.sh portal-steam-common.sh
portal_steam_install_script install-fex.sh portal-install-fex
portal_steam_install_script setup-games.sh portal-setup-games
portal_steam_install_script install-proton-stack.sh portal-install-proton-stack
portal_steam_install_script reinstall-proton.sh portal-reinstall-proton
portal_steam_install_script reinstall-steam.sh portal-reinstall-steam
portal_steam_install_script install-controller-support.sh portal-install-controller
portal_steam_install_script restore-portal-wayland.sh portal-restore-wayland
portal_steam_install_script fix-portal-desktop.sh portal-fix-desktop
portal_steam_install_script enable-portal-login-choice.sh portal-enable-login-choice
install -m755 "${SRC}/enable-portal-login-choice.sh" /usr/local/bin/portal-try-x11-gaming 2>/dev/null || \
	install -m755 "${SRC}/try-portal-x11-gaming.sh" /usr/local/bin/portal-try-x11-gaming 2>/dev/null || true
portal_steam_install_script portal-game-launch portal-game-launch
portal_steam_install_script diagnose-game.sh portal-diagnose-game
portal_steam_install_script reset-prefix.sh portal-reset-prefix

for f in /usr/local/bin/portal-steam /usr/local/bin/portal-install-steam \
	/usr/local/bin/portal-reinstall-proton /usr/local/bin/portal-reinstall-steam \
	/usr/local/bin/portal-setup-games \
	/usr/local/bin/portal-game-launch /usr/local/bin/portal-diagnose-game \
	/usr/local/bin/portal-reset-prefix; do
	[[ -f "${f}" ]] || continue
	sed -i 's|SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE\[0\]}")" && pwd)"|SCRIPT_DIR="/usr/local/bin"|' "${f}"
done

install -m644 "${SRC}/share/applications/portal-steam.desktop" /usr/share/applications/ 2>/dev/null || true

if [[ "${FULL_SETUP}" -eq 1 ]]; then
	echo ""
	echo "[portal-steam] --full: running complete Steam + Proton + FEX reinstall..."
	export PORTAL_STEAM_USER
	bash "${SRC}/reinstall-steam.sh" --skip-scripts
else
	echo ""
	echo "Installed commands in /usr/local/bin:"
	echo "  sudo portal-reinstall-steam              Complete reinstall (recommended after start-over)"
	echo "  sudo bash install-portal-steam.sh --full   Same (from bundle directory)"
	echo ""
	echo "  portal-install-steam --force   Steam client + libvpx6 + CachyOS only"
	echo "  portal-reinstall-proton        Valve Proton 11 + CachyOS only"
	echo "  portal-steam --gaming          Launch Big Picture + gamescope"
	echo "  portal-setup-games             FEX rootfs + Vulkan guest"
	echo "  sudo portal-install-proton-stack   System Proton env"
	echo "  portal-diagnose-game           Debug while game runs"
fi
