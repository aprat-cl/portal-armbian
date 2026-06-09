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

# Stock Ubuntu gamescope lacks ROCKNIX/Valve-only flags (--use-rotation-shader, etc.).
portal_steam_gamescope_help() {
	command -v gamescope >/dev/null 2>&1 || return 1
	gamescope --help 2>&1
}

portal_steam_gamescope_has_flag() {
	portal_steam_gamescope_help | grep -qF -- "$1"
}

portal_steam_exec_gamescope() {
	local -a cmd=(gamescope -W "${W}" -H "${H}" -r "${REFRESH_HZ}")

	if portal_steam_gamescope_has_flag '--backend'; then
		cmd+=(--backend wayland)
	fi
	if portal_steam_gamescope_has_flag '--force-orientation'; then
		cmd+=(--force-orientation left)
	fi
	if portal_steam_gamescope_has_flag '--use-rotation-shader'; then
		cmd+=(--use-rotation-shader)
	fi
	if portal_steam_gamescope_has_flag '--xwayland-count'; then
		cmd+=(--xwayland-count 2)
	fi
	if portal_steam_gamescope_has_flag '--mangoapp'; then
		cmd+=(--mangoapp)
	fi
	cmd+=(-e -- "$@")
	exec "${cmd[@]}"
}
