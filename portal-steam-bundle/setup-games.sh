#!/bin/bash
# Prepare FEX + Vulkan for Proton ARM64 games (run as odin2 after portal-install-fex).
# Steam UI stays native aarch64; games use FEX + Proton-CachyOS ARM64.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=portal-steam-common.sh
source "${SCRIPT_DIR}/portal-steam-common.sh"

portal_steam_init_paths
export HOME="${STEAM_HOME}"

ok() { echo -e "[\033[1;32mOK\033[0m] $*"; }
warn() { echo -e "[\033[1;33mWARN\033[0m] $*"; }
fail() { echo -e "[\033[1;31mFAIL\033[0m] $*" >&2; }

FEX_DATA="${HOME}/.local/share/fex-emu"
FEX_ROOTFS_UBUNTU="${FEX_DATA}/RootFS/Ubuntu_24.04.sqsh"
FEX_GUEST_LIB="${FEX_DATA}/RootFS/Ubuntu_24.04/usr/lib"

portal_steam_log "Portal game stack check (${STEAM_USER})..."

# --- FEX ---
if ! command -v FEXInterpreter >/dev/null 2>&1 && ! command -v FEX >/dev/null 2>&1; then
	fail "FEX not installed. Run: sudo portal-install-fex"
	exit 1
fi
ok "FEX installed"

if [[ ! -f "${FEX_ROOTFS_UBUNTU}" ]]; then
	portal_steam_log "Fetching FEX Ubuntu 24.04 rootfs (one-time, large download)..."
	FEXRootFSFetcher --distro-name=ubuntu --distro-version=24.04 -y -x || {
		fail "FEXRootFSFetcher failed. Try: FEXRootFSFetcher -y -x"
		exit 1
	}
fi
[[ -f "${FEX_ROOTFS_UBUNTU}" ]] && ok "FEX rootfs present" || warn "FEX rootfs missing"

mkdir -p "${HOME}/.config"
if [[ -d "${PORTAL_STEAM_SHARE}/fex-emu" ]]; then
	cp -r "${PORTAL_STEAM_SHARE}/fex-emu" "${HOME}/.config/"
	ok "FEX config installed (Vulkan thunk on)"
fi

# Adreno Vulkan inside FEX guest (ROCKNIX copies libvulkan_freedreno.so)
mkdir -p "${FEX_GUEST_LIB}"
if [[ -f /usr/share/fex-emu/libvulkan_freedreno.so ]]; then
	cp -f /usr/share/fex-emu/libvulkan_freedreno.so "${FEX_GUEST_LIB}/"
	ok "libvulkan_freedreno.so in FEX guest"
elif [[ -f /usr/lib/aarch64-linux-gnu/libvulkan.so.1 ]]; then
	ln -sf /usr/lib/aarch64-linux-gnu/libvulkan.so.1 "${FEX_GUEST_LIB}/libvulkan.so.1" 2>/dev/null || true
	warn "Using host libvulkan.so.1 in FEX guest (no freedreno blob)"
else
	warn "No Vulkan ICD for FEX guest — install mesa-vulkan-drivers"
fi

# binfmt must be on for Proton/x86 game binaries
if [[ -w /proc/sys/fs/binfmt_misc/status ]]; then
	echo 1 >/proc/sys/fs/binfmt_misc/status 2>/dev/null || true
fi
systemctl restart systemd-binfmt 2>/dev/null || true
ok "binfmt restarted (FEX handlers active)"

# --- Vulkan host ---
if command -v vulkaninfo >/dev/null 2>&1; then
	if vulkaninfo --summary 2>/dev/null | grep -qi 'deviceName'; then
		ok "Host Vulkan: $(vulkaninfo --summary 2>/dev/null | awk -F= '/deviceName/ {print $2; exit}' | tr -d ' ')"
	else
		warn "vulkaninfo ran but no GPU — install mesa-vulkan-drivers"
	fi
else
	warn "vulkaninfo not found — sudo apt install vulkan-tools mesa-vulkan-drivers"
fi

# --- Proton ---
portal_steam_link_proton_compat 2>/dev/null || true
cachy="$(find "${STEAM_DIR}/compatibilitytools.d" -maxdepth 1 -type d -name 'proton-cachyos-*-arm64' 2>/dev/null | head -n 1)"
if [[ -n "${cachy}" ]]; then
	ok "Proton-CachyOS: $(basename "${cachy}")"
else
	warn "Proton-CachyOS not found — run portal-install-steam"
fi

# --- Tips ---
echo ""
portal_steam_log "In Steam per-game Properties → Compatibility:"
echo "  Use: Proton-CachyOS * ARM64  (not empty 'Proton 11.0' stub)"
echo ""
portal_steam_log "If screen goes blank on launch, try game Launch Options:"
echo "  PROTON_LOG=1 %command%"
echo "  or windowed:  %command% -windowed"
echo ""
portal_steam_log "Logs after failed launch:"
echo "  tail -f ${HOME}/.steam/steam/logs/stderr.txt"
echo "  ls -lt ${STEAM_DIR}/steamapps/compatdata/*/pfx/drive_c/users/steamuser/Temp/ 2>/dev/null | head"
echo ""
portal_steam_log "First game launch can take several minutes (FEX + pressure-vessel)."
