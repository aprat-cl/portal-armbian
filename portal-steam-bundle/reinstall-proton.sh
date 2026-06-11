#!/bin/bash
# Reinstall Proton 11 (ARM64) + Proton-CachyOS on Ayn Odin 2 Portal — nothing else.
# Lives in portal-steam-bundle/; copy the bundle to the device or run from there.
#
#   cd portal-steam-bundle
#   sudo -u aprat bash reinstall-proton.sh
#
# Env overrides: STEAM_USER  STEAM_GAMES  (default ~/games/steam)

set -euo pipefail

PROTON_CACHYOS_VER="11.0-20260521-slr"
PROTON_CACHYOS_TAR="proton-cachyos-${PROTON_CACHYOS_VER}-arm64.tar.xz"
PROTON_CACHYOS_DIR="proton-cachyos-${PROTON_CACHYOS_VER}-arm64"
PROTON_CACHYOS_URL="https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-${PROTON_CACHYOS_VER}/${PROTON_CACHYOS_TAR}"

PROTON11_APPID="4628740"
SLR4_APPID="4185400"
PROTON11_NAME="Proton 11.0 (ARM64)"
SLR4_NAME="SteamLinuxRuntime_4-arm64"

DO_CACHYOS=1
DO_VALVE=1

log()  { echo -e "[\033[1;34mproton\033[0m] $*"; }
die()  { echo -e "[\033[1;31mproton\033[0m] $*" >&2; exit 1; }

usage() {
	cat <<'EOF'
reinstall-proton.sh — delete broken Proton, download fresh copies

  bash reinstall-proton.sh              Both Valve Proton 11 + Proton-CachyOS
  bash reinstall-proton.sh --cachyos-only
  bash reinstall-proton.sh --valve-only
  bash reinstall-proton.sh --verify     Check only, no changes

Run as Steam user: sudo -u aprat bash reinstall-proton.sh
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--cachyos-only) DO_VALVE=0; shift ;;
		--valve-only)   DO_CACHYOS=0; shift ;;
		--verify)       VERIFY_ONLY=1; shift ;;
		-h|--help)      usage; exit 0 ;;
		*) die "Unknown option: $1" ;;
	esac
done

# --- paths ---
STEAM_USER="${STEAM_USER:-${SUDO_USER:-${USER}}}"
STEAM_HOME="$(getent passwd "${STEAM_USER}" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "${STEAM_HOME}" ]] || STEAM_HOME="${HOME}"

STEAM_GAMES="${STEAM_GAMES:-${STEAM_HOME}/games/steam}"
STEAM_DIR="${STEAM_HOME}/.local/share/Steam"
STEAM_DOT="${STEAM_HOME}/.steam"
STEAM_CLIENT="${STEAM_DIR}/steamrtarm64/steam"
STEAM_LIB="${STEAM_DIR}/lib/aarch64-linux-gnu"

# Resolve actual library root (Portal usually symlinks ~/.local/share/Steam → ~/games/steam).
if [[ -d "${STEAM_GAMES}/steamapps" ]]; then
	:
elif [[ -L "${STEAM_DIR}" ]]; then
	STEAM_GAMES="$(readlink -f "${STEAM_DIR}")"
elif [[ -d "${STEAM_DIR}/steamapps" ]]; then
	STEAM_GAMES="${STEAM_DIR}"
fi

COMPAT="${STEAM_GAMES}/compatibilitytools.d"
PROTON_DIR="${STEAM_GAMES}/steamapps/common/${PROTON11_NAME}"
SLR4_DIR="${STEAM_GAMES}/steamapps/common/${SLR4_NAME}"

[[ "$(id -un)" == "${STEAM_USER}" ]] || die "Run as ${STEAM_USER}: sudo -u ${STEAM_USER} bash $0"
export HOME="${STEAM_HOME}"

ok_proton11() { [[ -x "${PROTON_DIR}/proton" ]]; }
ok_cachyos() {
	local d
	d="$(find "${COMPAT}" -maxdepth 1 -type d -name 'proton-cachyos-*-arm64' 2>/dev/null | sort -V | tail -n 1)"
	[[ -n "${d}" && -x "${d}/proton" ]]
}
ok_slr4() { [[ -x "${SLR4_DIR}/_v2-entry-point" ]]; }

verify() {
	local fail=0
	if [[ "${DO_VALVE}" -eq 1 ]]; then
		ok_proton11 && log "OK  ${PROTON11_NAME}" || { log "MISS  ${PROTON11_NAME}"; fail=1; }
		ok_slr4     && log "OK  ${SLR4_NAME}"     || { log "MISS  ${SLR4_NAME}"; fail=1; }
	fi
	if [[ "${DO_CACHYOS}" -eq 1 ]]; then
		ok_cachyos && log "OK  Proton-CachyOS ARM64" || { log "MISS  Proton-CachyOS"; fail=1; }
		[[ -L "${COMPAT}/Proton11ARM" ]] && log "OK  Proton11ARM → $(readlink "${COMPAT}/Proton11ARM")" \
			|| { log "MISS  ${COMPAT}/Proton11ARM"; fail=1; }
	fi
	return "${fail}"
}

[[ "${VERIFY_ONLY:-0}" -eq 1 ]] && { verify; exit $?; }

command -v wget >/dev/null 2>&1 || die "Need wget: sudo apt install wget"

write_toolmanifest() {
	local dest="$1"
	cat >"${dest}/toolmanifest.vdf" <<'VDF'
"manifest"
{
  "version" "2"
  "commandline" "/proton %verb%"
  "use_sessions" "1"
  "compatmanager_layer_name" "proton"
}
VDF
}

write_compat_vdf() {
	mkdir -p "${COMPAT}"
	cat >"${COMPAT}/compatibilitytool.vdf" <<'VDF'
"compatibilitytools"
{
  "compat_tools"
  {
    "proton11_arm64"
    {
      "install_path" "Proton11ARM"
      "display_name" "Proton 11.0 (ARM64)"
      "from_oslist"  "windows"
      "to_oslist"    "linux"
    }
  }
}
VDF
}

steam_ld_path() {
	local rt
	rt="$(echo "${STEAM_DIR}"/steam-runtime-steamrt-arm64/steamrt3c_platform_*/files/lib/aarch64-linux-gnu 2>/dev/null | head -n 1)"
	local -a p=()
	[[ -d "${STEAM_LIB}" ]] && p+=("${STEAM_LIB}")
	[[ -d "${rt}" ]] && p+=("${rt}" "${rt}/nss")
	[[ -d "${STEAM_DIR}/steamrtarm64" ]] && p+=("${STEAM_DIR}/steamrtarm64")
	local IFS=:
	echo "${p[*]}"
}

run_steam() {
	[[ -x "${STEAM_CLIENT}" ]] || die "Steam ARM64 client missing at ${STEAM_CLIENT}"
	mkdir -p "${STEAM_DIR}/package"
	echo publicbeta >"${STEAM_DIR}/package/beta"
	env LD_LIBRARY_PATH="$(steam_ld_path)" "$@"
}

remove_cachyos() {
	log "Removing old Proton-CachyOS..."
	rm -rf "${COMPAT}"/proton-cachyos-*-arm64
	rm -f "${COMPAT}/${PROTON_CACHYOS_TAR}"
	rm -f "${COMPAT}/Proton11ARM"
}

install_cachyos() {
	remove_cachyos
	mkdir -p "${COMPAT}"
	local tar="${COMPAT}/${PROTON_CACHYOS_TAR}"
	local dir="${COMPAT}/${PROTON_CACHYOS_DIR}"

	log "Downloading Proton-CachyOS ${PROTON_CACHYOS_VER}..."
	wget -c -t 5 -O "${tar}" "${PROTON_CACHYOS_URL}"
	tar -xf "${tar}" -C "${COMPAT}"
	rm -f "${tar}"
	sed -i '/require_tool_appid/d' "${dir}/toolmanifest.vdf" 2>/dev/null || true
	chmod +x "${dir}/proton"
	install_cachyos_user_settings "${dir}"

	write_compat_vdf
	ln -sfn "${dir}" "${COMPAT}/Proton11ARM"
	log "Proton11ARM → ${PROTON_CACHYOS_DIR}"
}

install_cachyos_user_settings() {
	local dir="$1"
	local src=""
	for src in \
		"/usr/share/portal-steam/proton-user_settings.py" \
		"$(dirname "$0")/share/proton-user_settings.py"; do
		[[ -f "${src}" ]] || continue
		cp -f "${src}" "${dir}/user_settings.py"
		log "Installed user_settings.py from ${src}"
		return 0
	done
	cat >"${dir}/user_settings.py" <<'PY'
user_settings = {
	"SDL_VIDEODRIVER": "x11",
	"GDK_BACKEND": "x11",
	"QT_QPA_PLATFORM": "xcb",
	"TU_DEBUG": "deck_emu",
	"VK_ICD_FILENAMES": "/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json",
}
PY
	log "Installed default user_settings.py"
}

remove_valve_proton() {
	log "Removing broken Valve Proton 11 + runtime..."
	rm -rf "${PROTON_DIR}" "${SLR4_DIR}"
	rm -f "${STEAM_GAMES}/steamapps/appmanifest_${PROTON11_APPID}.acf"
	rm -f "${STEAM_GAMES}/steamapps/appmanifest_${SLR4_APPID}.acf"
	rm -rf "${STEAM_GAMES}/steamapps/downloading/${PROTON11_APPID}"
	rm -rf "${STEAM_GAMES}/steamapps/downloading/${SLR4_APPID}"
}

install_valve_proton() {
	remove_valve_proton
	mkdir -p "${PROTON_DIR}" "${COMPAT}"
	write_toolmanifest "${PROTON_DIR}"
	write_compat_vdf

	log "Asking Steam to download ${PROTON11_NAME} + ${SLR4_NAME} (~3.5 GB)..."
	log "Keep Steam running until both show OK in --verify"

	local appid
	for appid in "${SLR4_APPID}" "${PROTON11_APPID}"; do
		run_steam "${STEAM_CLIENT}" -noreactlogin -silent "steam://install/${appid}" -exitsteam \
			2>/dev/null || true
	done
	run_steam "${STEAM_CLIENT}" -steamdeck -exitsteam 2>/dev/null || true

	local deadline=$((SECONDS + 900))
	while (( SECONDS < deadline )); do
		ok_proton11 && ok_slr4 && { log "Valve Proton download complete."; return 0; }
		sleep 5
		pgrep -f steamrtarm64/steam >/dev/null && printf '.'
	done
	echo ""
	log "Still downloading — open Steam and wait for tool updates, then: bash $0 --verify"
}

# --- main ---
log "User ${STEAM_USER}  library ${STEAM_GAMES}"

if [[ "${DO_CACHYOS}" -eq 1 ]]; then
	install_cachyos
fi

if [[ "${DO_VALVE}" -eq 1 ]]; then
	install_valve_proton
fi

# If only CachyOS, still wire Proton11ARM symlink
if [[ "${DO_CACHYOS}" -eq 1 && "${DO_VALVE}" -eq 0 ]]; then
	write_compat_vdf
	d="$(find "${COMPAT}" -maxdepth 1 -type d -name 'proton-cachyos-*-arm64' | sort -V | tail -n 1)"
	ln -sfn "${d}" "${COMPAT}/Proton11ARM"
fi

echo ""
log "Result:"
if verify; then
	log "Done. In Steam: Settings → Compatibility → Proton-CachyOS ARM64"
else
	log "Incomplete — finish downloads in Steam, then: bash $0 --verify"
fi
