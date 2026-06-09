#!/bin/bash
# Shared helpers for Portal Steam on Armbian KDE Wayland.
# Target: Valve Steam ARM64 *public beta* client (steamrtarm64), not stable amd64/FEX.

# Valve public-beta ARM64 client + steamrt runtime (ROCKNIX / Steam Deck ARM path).
readonly PORTAL_STEAM_BETA_CHANNEL="publicbeta"
readonly PORTAL_STEAM_RUNTIME_URL="https://repo.steampowered.com/steamrt3c/images/latest-public-beta/steam-runtime-steamrt-arm64.tar.xz"
readonly PORTAL_STEAM_MANIFEST_URL="https://client-update.fastly.steamstatic.com/steam_client_publicbeta_linuxarm64"
readonly PORTAL_STEAM_CDN="https://client-update.steamstatic.com"

portal_steam_init_paths() {
	STEAM_USER="${PORTAL_STEAM_USER:-${SUDO_USER:-${USER}}}"
	STEAM_HOME="$(getent passwd "${STEAM_USER}" | cut -d: -f6)"
	[[ -n "${STEAM_HOME}" ]] || STEAM_HOME="${HOME}"

	STEAM_DIR="${PORTAL_STEAM_DIR:-${STEAM_HOME}/.local/share/Steam}"
	STEAM_GAMES_ROOT="${PORTAL_STEAM_GAMES:-${STEAM_HOME}/games/steam}"
	STEAM_DOT="${STEAM_HOME}/.steam"
	STEAM_CLIENT="${STEAM_DIR}/steamrtarm64/steam"
	STEAM_LIB="${STEAM_DIR}/lib/aarch64-linux-gnu"
	STEAM_RUNTIME_DIR="${STEAM_DIR}/steam-runtime-steamrt-arm64"
	PROTON_NAME="Proton 11.0 (ARM64)"
	PROTON_DIR="${STEAM_DIR}/steamapps/common/${PROTON_NAME}"
	PORTAL_STEAM_SHARE="${PORTAL_STEAM_SHARE:-/usr/share/portal-steam}"
}

portal_steam_log() { echo -e "[\033[1;34mportal-steam\033[0m] $*"; }
portal_steam_die() { echo -e "[\033[1;31mportal-steam\033[0m] $*" >&2; exit 1; }

portal_steam_link_proton_compat() {
	local dest_dir="${STEAM_DIR}/compatibilitytools.d"
	local cachy
	cachy="$(find "${dest_dir}" -maxdepth 1 -type d -name 'proton-cachyos-*-arm64' 2>/dev/null | sort -V | tail -n 1)"
	[[ -n "${cachy}" ]] || return 1
	mkdir -p "${dest_dir}"
	ln -sfn "${cachy}" "${dest_dir}/Proton11ARM"
	cp -f "${PORTAL_STEAM_SHARE}/compatibilitytool.vdf" "${dest_dir}/" 2>/dev/null || true
}

portal_steam_ensure_beta_channel() {
	mkdir -p "${STEAM_DIR}/package"
	echo "${PORTAL_STEAM_BETA_CHANNEL}" >"${STEAM_DIR}/package/beta"
}

portal_steam_assert_native_arm64() {
	[[ -x "${STEAM_CLIENT}" ]] || portal_steam_die "ARM64 beta client missing at ${STEAM_CLIENT}. Run: portal-install-steam"
	case "${STEAM_CLIENT}" in
		*/steamrtarm64/steam) ;;
		*) portal_steam_die "Refusing non-beta ARM64 client path: ${STEAM_CLIENT}" ;;
	esac
	if command -v file >/dev/null 2>&1; then
		file -b "${STEAM_CLIENT}" | grep -qE 'aarch64|ARM' || \
			portal_steam_die "Refusing non-ARM64 binary: ${STEAM_CLIENT}"
	fi
	if [[ -f "${STEAM_DIR}/package/beta" ]]; then
		grep -qx "${PORTAL_STEAM_BETA_CHANNEL}" "${STEAM_DIR}/package/beta" || \
			portal_steam_log "Note: resetting Steam channel to ${PORTAL_STEAM_BETA_CHANNEL}"
	fi
	portal_steam_ensure_beta_channel
}

portal_steam_read_display_geometry() {
	W="${PORTAL_STEAM_W:-1920}"
	H="${PORTAL_STEAM_H:-1080}"
	REFRESH_HZ="${PORTAL_STEAM_REFRESH:-60}"
	if command -v wlr-randr >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
		local line
		line="$(wlr-randr 2>/dev/null | awk '/current/ {print $1, $3; exit}')"
		if [[ -n "${line}" ]]; then
			read -r W H <<<"${line}"
		fi
	fi
}

portal_steam_client_ready() {
	[[ -x "${STEAM_CLIENT}" ]]
}

portal_steam_launch_flags() {
	# shellcheck disable=SC2034
	STEAM_LAUNCH_FLAGS=(
		-steamdeck -steamos3
		-noverifyfiles -nobootstrapupdate -skipinitialbootstrap
		-norepairfiles -noshaders
	)
}

# ROCKNIX ARM64 Steam uses SDL_VIDEODRIVER=x11; Proton/DXVK presents via XWayland on KDE.
portal_steam_apply_session_env() {
	if [[ -f "${PORTAL_STEAM_SHARE}/portal-proton.env" ]]; then
		# shellcheck source=/dev/null
		source "${PORTAL_STEAM_SHARE}/portal-proton.env"
	elif [[ -f /usr/share/portal-steam/portal-proton.env ]]; then
		# shellcheck source=/dev/null
		source /usr/share/portal-steam/portal-proton.env
	fi
	if [[ -f "${STEAM_HOME}/.config/portal-steam/env.sh" ]]; then
		# shellcheck source=/dev/null
		source "${STEAM_HOME}/.config/portal-steam/env.sh"
	fi
}

# Proton user_settings.py — env for every game using Proton-CachyOS ARM64 (official hook).
portal_steam_install_proton_user_settings() {
	local proton_dir
	proton_dir="$(find "${STEAM_DIR}/compatibilitytools.d" -maxdepth 1 -type d -name 'proton-cachyos-*-arm64' 2>/dev/null | sort -V | tail -n 1)"
	[[ -n "${proton_dir}" ]] || return 0
	local dest="${proton_dir}/user_settings.py"
	[[ -f "${PORTAL_STEAM_SHARE}/proton-user_settings.py" ]] || return 0
	if [[ -f "${dest}" ]] && grep -q 'PORTAL_PROTON' "${dest}" 2>/dev/null; then
		return 0
	fi
	portal_steam_log "Installing Proton user_settings.py (all games using CachyOS ARM64)..."
	cp -f "${PORTAL_STEAM_SHARE}/proton-user_settings.py" "${dest}"
}

portal_steam_runtime_platform_lib() {
	echo "${STEAM_DIR}"/steam-runtime-steamrt-arm64/steamrt3c_platform_*/files/lib/aarch64-linux-gnu
}

portal_steam_ld_library_path() {
	local -a paths=()
	local rt nss

	paths+=("${STEAM_LIB}")
	rt="$(portal_steam_runtime_platform_lib | head -n 1)"
	if [[ -d "${rt}" ]]; then
		paths+=("${rt}")
		nss="${rt}/nss"
		[[ -d "${nss}" ]] && paths+=("${nss}")
	fi
	[[ -d "${STEAM_DIR}/steamrtarm64" ]] && paths+=("${STEAM_DIR}/steamrtarm64")
	local IFS=:
	echo "${paths[*]}"
}

portal_steam_link_runtime_libs() {
	mkdir -p "${STEAM_LIB}"
	local rt target
	rt="$(portal_steam_runtime_platform_lib | head -n 1)"
	[[ -d "${rt}" ]] || return 0

	target="$(echo "${rt}"/libibus-1.0.so.5.* | head -n 1)"
	if [[ -f "${target}" ]]; then
		ln -sf "${target}" "${STEAM_LIB}/libibus-1.0.so.5"
	fi
}

# Noble ships libvpx9 (.so.9); Steam beta expects libvpx.so.6 from steamrt or Jammy.
portal_steam_ensure_libvpx() {
	mkdir -p "${STEAM_LIB}"
	[[ -e "${STEAM_LIB}/libvpx.so.6" ]] && return 0

	local rt target deb extract
	rt="$(portal_steam_runtime_platform_lib | head -n 1)"
	if [[ -d "${rt}" ]]; then
		target="$(find "${rt}" -name 'libvpx.so.6*' 2>/dev/null | head -n 1)"
		if [[ -z "${target}" ]]; then
			target="$(find "${rt}" -name 'libvpx.so*' 2>/dev/null | sort -V | tail -n 1)"
		fi
		if [[ -n "${target}" ]]; then
			ln -sf "${target}" "${STEAM_LIB}/libvpx.so.6"
			portal_steam_log "Linked libvpx.so.6 from Steam runtime."
			return 0
		fi
	fi

	portal_steam_log "libvpx.so.6 not in runtime — downloading libvpx-dev for ARM64..."
	deb="${STEAM_DIR}/.cache/libvpx-dev-arm64.deb"
	mkdir -p "${STEAM_DIR}/.cache"
	wget -c -t 5 -O "${deb}" \
		"http://ports.ubuntu.com/pool/main/libv/libvpx/libvpx-dev_1.8.2-1build1_arm64.deb" || \
		portal_steam_die "Could not download libvpx-dev. Check network."
	extract="${STEAM_DIR}/.cache/libvpx-dev"
	rm -rf "${extract}"
	dpkg-deb -x "${deb}" "${extract}"
	target="$(find "${extract}" -name 'libvpx.so.6*' 2>/dev/null | head -n 1)"
	[[ -n "${target}" ]] || portal_steam_die "libvpx.so.6 missing inside libvpx-dev deb."
	ln -sf "${target}" "${STEAM_LIB}/libvpx.so.6"
	portal_steam_log "Installed libvpx.so.6 shim for Steam beta client."
}

portal_steam_prepare_libs() {
	portal_steam_link_runtime_libs
	portal_steam_ensure_libvpx
}

portal_steam_run_once() {
	portal_steam_prepare_libs
	env LD_LIBRARY_PATH="$(portal_steam_ld_library_path)" "$@"
}

# Stock Ubuntu gamescope lacks ROCKNIX/Valve-only flags (--use-rotation-shader, etc.).
portal_steam_gamescope_help() {
	command -v gamescope >/dev/null 2>&1 || return 1
	gamescope --help 2>&1
}

portal_steam_gamescope_has_flag() {
	portal_steam_gamescope_help | grep -qF -- "$1"
}

portal_steam_gamescope_build_cmd() {
	local backend="${1:-}"
	shift
	PORTAL_STEAM_GAMESCOPE_CMD=(
		gamescope -W "${W}" -H "${H}" -w "${W}" -h "${H}" -r "${REFRESH_HZ}" -f
	)
	if [[ -n "${backend}" ]] && portal_steam_gamescope_has_flag '--backend'; then
		PORTAL_STEAM_GAMESCOPE_CMD+=(--backend "${backend}")
	fi
	if portal_steam_gamescope_has_flag '--force-orientation'; then
		PORTAL_STEAM_GAMESCOPE_CMD+=(--force-orientation left)
	fi
	if portal_steam_gamescope_has_flag '--use-rotation-shader'; then
		PORTAL_STEAM_GAMESCOPE_CMD+=(--use-rotation-shader)
	fi
	if portal_steam_gamescope_has_flag '--xwayland-count'; then
		PORTAL_STEAM_GAMESCOPE_CMD+=(--xwayland-count 2)
	fi
	if portal_steam_gamescope_has_flag '--mangoapp'; then
		PORTAL_STEAM_GAMESCOPE_CMD+=(--mangoapp)
	fi
	PORTAL_STEAM_GAMESCOPE_CMD+=(-e -- "$@")
}

# Try SDL first (less Vulkan nesting), then wayland; return 0 if Steam session ended cleanly.
portal_steam_try_gamescope() {
	local backend
	for backend in sdl wayland ""; do
		[[ "${backend}" == "" ]] && ! portal_steam_gamescope_has_flag '--backend' && backend=""
		portal_steam_gamescope_build_cmd "${backend}" "$@"
		if [[ -n "${backend}" ]]; then
			portal_steam_log "Trying gamescope --backend ${backend} (${W}x${H}@${REFRESH_HZ})..."
		else
			portal_steam_log "Trying gamescope (${W}x${H}@${REFRESH_HZ})..."
		fi
		if "${PORTAL_STEAM_GAMESCOPE_CMD[@]}"; then
			return 0
		fi
		portal_steam_log "gamescope backend '${backend:-default}' failed."
	done
	return 1
}
