#!/bin/bash
# Full Portal Steam reinstall: system stack + Steam client + Proton + FEX + games prep.
# Keeps installed games in ~/games/steam/steamapps/ (or your STEAM_GAMES path).
#
#   cd portal-steam-bundle
#   sudo bash install-portal-steam.sh --full
#   # or, if scripts already in /usr/local/bin:
#   sudo bash reinstall-steam.sh
#
# Env: PORTAL_STEAM_USER=aprat  PORTAL_STEAM_GAMES=~/games/steam

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_SCRIPTS=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--skip-scripts) SKIP_SCRIPTS=1; shift ;;
		-h | --help)
			cat <<'EOF'
reinstall-steam.sh — full Steam + Proton + FEX setup (keeps game installs)

  sudo bash reinstall-steam.sh              Use /usr/local/bin scripts
  sudo bash install-portal-steam.sh --full  Install scripts + run this

Steps: stop Steam → system Proton stack → FEX → Steam client → Proton 11 → setup-games
EOF
			exit 0
			;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
done

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash reinstall-steam.sh" >&2
	exit 1
fi

STEAM_USER="${PORTAL_STEAM_USER:-${SUDO_USER:-}}"
if [[ -z "${STEAM_USER}" || "${STEAM_USER}" == "root" ]]; then
	for u in aprat portal odin2; do
		if getent passwd "${u}" >/dev/null 2>&1; then
			STEAM_USER="${u}"
			break
		fi
	done
fi
[[ -n "${STEAM_USER}" && "${STEAM_USER}" != "root" ]] || {
	echo "Set PORTAL_STEAM_USER or run: sudo -u aprat bash reinstall-steam.sh" >&2
	exit 1
}

STEAM_HOME="$(getent passwd "${STEAM_USER}" | cut -d: -f6)"
[[ -d "${STEAM_HOME}" ]] || { echo "Home missing for ${STEAM_USER}" >&2; exit 1; }

log() { echo -e "[\033[1;36mreinstall-steam\033[0m] $*"; }

run_as_steam() {
	sudo -u "${STEAM_USER}" env \
		HOME="${STEAM_HOME}" \
		PORTAL_STEAM_USER="${STEAM_USER}" \
		PORTAL_STEAM_GAMES="${PORTAL_STEAM_GAMES:-}" \
		"$@"
}

run_root_script() {
	local bin="$1"
	local bundle_sh="${2:-${bin}}"
	if [[ -x "/usr/local/bin/${bin}" ]]; then
		"/usr/local/bin/${bin}"
	elif [[ -f "${SCRIPT_DIR}/${bundle_sh}.sh" ]]; then
		bash "${SCRIPT_DIR}/${bundle_sh}.sh"
	else
		echo "Missing ${bin} (looked for ${bundle_sh}.sh)" >&2
		exit 1
	fi
}

log "Full Steam reinstall for user ${STEAM_USER} (games library kept)"

log "[1/5] Stopping Steam..."
pkill -f 'steamrtarm64/steam' 2>/dev/null || true
pkill -x steam 2>/dev/null || true
sleep 2

log "[2/5] System Proton stack (lib64, Vulkan env, gamescope)..."
run_root_script portal-install-proton-stack install-proton-stack

log "[3/5] FEX (x86 emulation for Proton games)..."
run_root_script portal-install-fex install-fex

log "[4/5] Steam ARM64 client + runtime + libvpx6 + Proton-CachyOS..."
run_as_steam /usr/local/bin/portal-install-steam --force 2>/dev/null || \
	run_as_steam bash "${SCRIPT_DIR}/install-steam.sh" --force

log "[4b/5] Valve Proton 11 + SteamLinuxRuntime_4-arm64..."
run_as_steam /usr/local/bin/portal-reinstall-proton 2>/dev/null || \
	run_as_steam bash "${SCRIPT_DIR}/reinstall-proton.sh"

log "[5/5] FEX rootfs + Vulkan guest + Proton user settings..."
run_as_steam /usr/local/bin/portal-setup-games 2>/dev/null || \
	run_as_steam bash "${SCRIPT_DIR}/setup-games.sh"

echo ""
log "Done."
echo ""
echo "  Launch:  portal-steam --gaming"
echo "  Verify:  portal-reinstall-proton --verify"
echo "  Debug:   portal-diagnose-game"
echo ""
echo "  Steam → Settings → Compatibility → Proton-CachyOS ARM64"
