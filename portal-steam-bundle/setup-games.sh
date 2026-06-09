#!/bin/bash
# Prepare FEX rootfs + Vulkan for Proton ARM64 games (run as odin2, after portal-install-fex).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=portal-steam-common.sh
source "${SCRIPT_DIR}/portal-steam-common.sh"

portal_steam_init_paths
export HOME="${STEAM_HOME}"

ok() { echo -e "[\033[1;32mOK\033[0m] $*"; }
warn() { echo -e "[\033[1;33mWARN\033[0m] $*"; }
fail() { echo -e "[\033[1;31mFAIL\033[0m] $*" >&2; }

# FEX names rootfs Ubuntu_24_04 (underscores), not Ubuntu_24.04
readonly FEX_ROOTFS_NAME="Ubuntu_24_04"
FEX_DATA="${HOME}/.local/share/fex-emu"
FEX_ROOTFS_SQSH="${FEX_DATA}/RootFS/${FEX_ROOTFS_NAME}.sqsh"
FEX_ROOTFS_DIR="${FEX_DATA}/RootFS/${FEX_ROOTFS_NAME}"
FEX_GUEST_LIB="${FEX_ROOTFS_DIR}/usr/lib"

portal_steam_log "Portal game stack (${STEAM_USER})..."

portal_fex_installed() {
	command -v FEX >/dev/null 2>&1 || [[ -x /usr/bin/FEX ]] || \
		dpkg -l 'fex-emu-armv8.*' 2>/dev/null | grep -q '^ii'
}

if ! portal_fex_installed; then
	fail "FEX packages missing. Run: sudo portal-install-fex"
	exit 1
fi
ok "FEX package installed"

# squashfs mount needs these
if ! command -v unsquashfs >/dev/null 2>&1 || ! command -v squashfuse >/dev/null 2>&1; then
	warn "Install squashfs-tools + squashfuse (sudo apt install squashfs-tools squashfuse)"
fi

portal_steam_install_fex_config() {
	mkdir -p "${HOME}/.config/fex-emu" "${HOME}/.local/share/fex-emu/RootFS"
	if [[ -d "${PORTAL_STEAM_SHARE}/fex-emu" ]]; then
		cp -r "${PORTAL_STEAM_SHARE}/fex-emu/." "${HOME}/.config/fex-emu/"
	fi
	# Legacy path some tools still read
	mkdir -p "${HOME}/.fex-emu"
	ln -sf "${HOME}/.config/fex-emu/Config.json" "${HOME}/.fex-emu/Config.json" 2>/dev/null || true
	ln -sf "${HOME}/.local/share/fex-emu/RootFS" "${HOME}/.fex-emu/RootFS" 2>/dev/null || true
}

portal_steam_fetch_fex_rootfs() {
	if [[ -f "${FEX_ROOTFS_SQSH}" ]]; then
		return 0
	fi
	# Old wrong filename from earlier scripts
	if [[ -f "${FEX_DATA}/RootFS/Ubuntu_24.04.sqsh" ]]; then
		mv "${FEX_DATA}/RootFS/Ubuntu_24.04.sqsh" "${FEX_ROOTFS_SQSH}"
		return 0
	fi
	portal_steam_log "Downloading FEX x86-64 rootfs (Ubuntu 24.04, ~500MB, one-time)..."
	if command -v FEXRootFSFetcher >/dev/null 2>&1; then
		FEXRootFSFetcher --distro-name=ubuntu --distro-version=24.04 -y -x || true
	fi
	if [[ ! -f "${FEX_ROOTFS_SQSH}" ]]; then
		FEXRootFSFetcher -y -x || fail "FEXRootFSFetcher failed. Run: FEXRootFSFetcher"
	fi
}

portal_steam_fex_smoke_test() {
	local fex_bin
	fex_bin="$(command -v FEX 2>/dev/null || echo /usr/bin/FEX)"
	FEXServer -k 2>/dev/null || true
	if out="$("${fex_bin}" /usr/bin/uname -m 2>&1)"; then
		[[ "${out}" == *x86_64* ]] && return 0
	fi
	# Show FEX error to user
	"${fex_bin}" /usr/bin/uname -m 2>&1 | head -5 || true
	return 1
}

portal_steam_install_fex_config
portal_steam_fetch_fex_rootfs

if [[ -f "${FEX_ROOTFS_SQSH}" ]]; then
	ok "RootFS: ${FEX_ROOTFS_SQSH}"
else
	fail "RootFS missing at ${FEX_ROOTFS_SQSH}"
	echo "  Run as ${STEAM_USER}: FEXRootFSFetcher --distro-name=ubuntu --distro-version=24.04 -y -x" >&2
	exit 1
fi

# Verify Config.json RootFS name matches sqsh basename
if [[ -f "${HOME}/.config/fex-emu/Config.json" ]]; then
	if grep -q 'Ubuntu_24\.04' "${HOME}/.config/fex-emu/Config.json"; then
		sed -i 's/Ubuntu_24\.04/Ubuntu_24_04/g' "${HOME}/.config/fex-emu/Config.json"
		warn "Fixed RootFS name in Config.json (24.04 → 24_04)"
	fi
	grep -q '"RootFS": "Ubuntu_24_04"' "${HOME}/.config/fex-emu/Config.json" || \
		warn "Config RootFS should be Ubuntu_24_04 — check ~/.config/fex-emu/Config.json"
fi

if portal_steam_fex_smoke_test; then
	ok "FEX smoke test: uname -m → x86_64"
else
	fail "FEX still broken — rootfs or config wrong"
	echo "  Config:  ~/.config/fex-emu/Config.json" >&2
	echo "  RootFS:  ${FEX_ROOTFS_SQSH}" >&2
	echo "  Reset:   rm -rf ~/.local/share/fex-emu/RootFS && FEXRootFSFetcher -y -x" >&2
	exit 1
fi

# Vulkan guest lib (after FEX may mount rootfs dir)
if [[ -d "${FEX_ROOTFS_DIR}/usr/lib" ]]; then
	if [[ -f /usr/share/fex-emu/libvulkan_freedreno.so ]]; then
		cp -f /usr/share/fex-emu/libvulkan_freedreno.so "${FEX_GUEST_LIB}/" 2>/dev/null || true
	elif [[ -f /usr/lib/aarch64-linux-gnu/libvulkan.so.1 ]]; then
		ln -sf /usr/lib/aarch64-linux-gnu/libvulkan.so.1 "${FEX_GUEST_LIB}/libvulkan.so.1" 2>/dev/null || true
	fi
fi

systemctl restart systemd-binfmt 2>/dev/null || true
ok "binfmt active for game binaries"

if command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo --summary 2>/dev/null | grep -qi deviceName; then
	ok "Host Vulkan OK"
else
	warn "Run: sudo apt install mesa-vulkan-drivers vulkan-tools"
fi

portal_steam_link_proton_compat 2>/dev/null || true

echo ""
portal_steam_log "Steam game settings:"
echo "  Compatibility: Proton-CachyOS * ARM64"
echo "  First launch: wait 2–5 min (pressure-vessel + FEX)"
echo "  If black screen: game Launch Options →  %command% -windowed"
echo "  Debug: PROTON_LOG=1 %command%"
