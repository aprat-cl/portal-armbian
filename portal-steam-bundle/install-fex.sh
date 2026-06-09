#!/bin/bash
# Install FEX from the official PPA (Proton games). Steam UI stays native (portal-steam).
# Do NOT use InstallFEX.py here — it nests sudo and fails when this script already runs as root.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo portal-install-fex" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() { echo "[portal-install-fex] $*"; }
die() { echo "[portal-install-fex] ERROR: $*" >&2; exit 1; }

portal_fex_detect_pkg() {
	local features
	features="$(awk -F: '/^Features/ {print $2; exit}' /proc/cpuinfo)"
	# Match InstallFEX.py ARM version tiers (SM8550 = v8.4).
	if echo "${features}" | grep -q asimddp && echo "${features}" | grep -q flagm; then
		echo "fex-emu-armv8.4"
	elif echo "${features}" | grep -q fcma; then
		echo "fex-emu-armv8.2"
	else
		echo "fex-emu-armv8.0"
	fi
}

portal_fex_find_binary() {
	local p
	for p in /usr/bin/FEX /usr/bin/FEXInterpreter; do
		[[ -x "${p}" ]] && echo "${p}" && return 0
	done
	command -v FEX 2>/dev/null || command -v FEXInterpreter 2>/dev/null || return 1
}

log "Installing prerequisites..."
apt-get update
apt-get install -y software-properties-common curl ca-certificates gnupg \
	mesa-vulkan-drivers vulkan-tools libvulkan1

if ! apt-cache policy 2>/dev/null | grep -qE 'fex-emu/ubuntu|ppa\.launchpad\.net.*fex-emu'; then
	log "Adding PPA ppa:fex-emu/fex ..."
	add-apt-repository -y ppa:fex-emu/fex
fi

apt-get update

FEX_PKG="$(portal_fex_detect_pkg)"
log "CPU package: ${FEX_PKG} (Snapdragon 8 Gen 2 expects fex-emu-armv8.4)"

apt-get install -y "${FEX_PKG}" fex-emu-binfmt32 fex-emu-binfmt64

systemctl daemon-reload 2>/dev/null || true
systemctl enable fex-emu-binfmt32.service fex-emu-binfmt64.service 2>/dev/null || true
systemctl restart fex-emu-binfmt32.service fex-emu-binfmt64.service 2>/dev/null || true
systemctl restart systemd-binfmt 2>/dev/null || true

FEX_BIN="$(portal_fex_find_binary)" || die "FEX binary not found after package install. Check: dpkg -l ${FEX_PKG}"

log "Installed: ${FEX_BIN}"
"${FEX_BIN}" /usr/bin/uname -m 2>/dev/null && log "FEX smoke test OK (should print x86_64)" || \
	warn_smoke="FEX smoke test failed — may still work via binfmt for Steam games"

echo ""
echo "FEX is installed. The command is uppercase: FEX  (not 'fex')"
echo "As user odin2:"
echo "  portal-setup-games"
echo "  portal-steam --gamepadui"
