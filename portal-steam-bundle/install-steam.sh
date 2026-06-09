#!/bin/bash
# Install native ARM64 Steam client + runtime + Proton-CachyOS (FEX is separate, for games).
# Run as odin2 (or set PORTAL_STEAM_USER). Needs network on first run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=portal-steam-common.sh
source "${SCRIPT_DIR}/portal-steam-common.sh"

RUNTIME_TAR_URL="https://repo.steampowered.com/steamrt3c/images/latest-public-beta/steam-runtime-steamrt-arm64.tar.xz"
STEAM_MANIFEST_URL="https://client-update.fastly.steamstatic.com/steam_client_publicbeta_linuxarm64"
STEAM_CDN="https://client-update.steamstatic.com"
PROTON_CACHYOS_VERSION_FULL="11.0-20260521-slr"
PROTON_CACHYOS_TAR="proton-cachyos-${PROTON_CACHYOS_VERSION_FULL}-arm64.tar.xz"
PROTON_CACHYOS_DIR="proton-cachyos-${PROTON_CACHYOS_VERSION_FULL}-arm64"
PROTON_CACHYOS_URL="https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-${PROTON_CACHYOS_VERSION_FULL}/${PROTON_CACHYOS_TAR}"

portal_steam_init_paths

if [[ "$(id -un)" != "${STEAM_USER}" ]]; then
	portal_steam_die "Run as ${STEAM_USER}: sudo -u ${STEAM_USER} portal-install-steam"
fi

export HOME="${STEAM_HOME}"
cd "${HOME}"

link_steam_library() {
	portal_steam_log "Linking Steam library at ${STEAM_GAMES_ROOT}"
	if [[ -d "${STEAM_DIR}" && ! -L "${STEAM_DIR}" ]]; then
		rm -rf "${STEAM_DIR}"
	fi
	mkdir -p "${STEAM_GAMES_ROOT}/steamapps"
	ln -sfn "${STEAM_GAMES_ROOT}" "${STEAM_DIR}"
}

install_steam_runtime_arm64() {
	if [[ -d "${STEAM_RUNTIME_DIR}" ]]; then
		portal_steam_log "Steam runtime already present."
		return 0
	fi
	portal_steam_log "Downloading Steam ARM64 runtime..."
	local tar_path="${STEAM_DIR}/steam-runtime-steamrt-arm64.tar.xz"
	wget -c -t 5 -O "${tar_path}" "${RUNTIME_TAR_URL}"
	tar xvf "${tar_path}" -C "${STEAM_DIR}"
	rm -f "${tar_path}"

	local target
	target="$(echo "${STEAM_DIR}"/steam-runtime-steamrt-arm64/steamrt3c_platform_*/files/lib/aarch64-linux-gnu/libibus-1.0.so.5.* | head -n 1)"
	[[ -f "${target}" ]] || portal_steam_die "libibus not found in runtime."
	mkdir -p "${STEAM_LIB}"
	ln -sf "${target}" "${STEAM_LIB}/libibus-1.0.so.5"
}

install_steam_client_arm64() {
	if [[ -d "${STEAM_DIR}/steamrtarm64" ]]; then
		portal_steam_log "Steam client already present."
		return 0
	fi
	portal_steam_log "Downloading Steam ARM64 client..."
	local manifest target_file zip_path
	manifest="$(curl -fsSL "${STEAM_MANIFEST_URL}" | strings)"
	target_file="$(echo "${manifest}" | grep -oP 'bins_linuxarm64_linuxarm64\.zip\.(?!vz\.)[^"]+' | head -n 1)"
	[[ -n "${target_file}" ]] || portal_steam_die "Could not parse Steam client manifest."
	zip_path="${STEAM_DIR}/linuxarm64.zip"
	wget -c -t 5 -O "${zip_path}" "${STEAM_CDN}/${target_file}"
	unzip -o "${zip_path}" -d "${STEAM_DIR}"
	rm -f "${zip_path}"
	chmod +x "${STEAM_DIR}/steamrtarm64/steam"

	mkdir -p "${STEAM_DIR}/package"
	echo publicbeta >"${STEAM_DIR}/package/beta"
	mkdir -p "${STEAM_DOT}"
	ln -sfn "${STEAM_DIR}" "${STEAM_DOT}/steam"
	ln -sfn "${STEAM_DIR}/linuxarm64" "${STEAM_DOT}/sdkarm64"

	mkdir -p "${STEAM_DIR}/compatibilitytools.d/"
	ln -sfn "${PROTON_DIR}/" "${STEAM_DIR}/compatibilitytools.d/Proton11ARM"
	cp -f "${PORTAL_STEAM_SHARE}/compatibilitytool.vdf" "${STEAM_DIR}/compatibilitytools.d/"
}

install_bundled_proton_files() {
	portal_steam_log "Installing Proton tool manifests..."
	mkdir -p "${STEAM_DOT}" "${PROTON_DIR}/"
	cp -f "${PORTAL_STEAM_SHARE}/toolmanifest.vdf" "${PROTON_DIR}/"
	cp -f "${PORTAL_STEAM_SHARE}/registry.vdf" "${STEAM_DOT}/"
}

install_proton_cachyos() {
	local dest_dir="${STEAM_DIR}/compatibilitytools.d"
	local tar_path="${dest_dir}/${PROTON_CACHYOS_TAR}"
	local extracted_dir="${dest_dir}/${PROTON_CACHYOS_DIR}"
	local manifest_file="${extracted_dir}/toolmanifest.vdf"

	if [[ -d "${dest_dir}" ]]; then
		for old_dir in "${dest_dir}"/proton-cachyos-*-arm64; do
			[[ -d "${old_dir}" ]] || continue
			[[ "${old_dir}" == "${extracted_dir}" ]] && continue
			portal_steam_log "Removing old $(basename "${old_dir}")"
			rm -rf "${old_dir}"
		done
	fi

	if [[ -d "${extracted_dir}" ]]; then
		portal_steam_log "Proton-CachyOS already installed."
		return 0
	fi

	portal_steam_log "Downloading Proton-CachyOS ARM64..."
	mkdir -p "${dest_dir}"
	wget -c -t 5 -O "${tar_path}" "${PROTON_CACHYOS_URL}"
	tar -xvf "${tar_path}" -C "${dest_dir}"
	rm -f "${tar_path}"
	if [[ -f "${manifest_file}" ]]; then
		sed -i '/require_tool_appid/d' "${manifest_file}"
	fi
}

run_steam_first_launch() {
	portal_steam_log "First-launch bootstrap (native aarch64 client, may flash Steam briefly)..."
	portal_steam_assert_native_arm64
	unset MESA_LOADER_DRIVER_OVERRIDE
	LD_LIBRARY_PATH="${STEAM_LIB}/" "${STEAM_CLIENT}" -steamdeck -exitsteam || true
}

install_desktop_stub() {
	mkdir -p "${HOME}/.local/share/applications"
	touch "${HOME}/.local/share/applications/Steam.desktop"
}

portal_steam_log "Starting native ARM64 Steam installation for ${STEAM_USER}..."
link_steam_library
install_desktop_stub
install_steam_runtime_arm64
install_steam_client_arm64
install_bundled_proton_files
install_proton_cachyos
run_steam_first_launch

portal_steam_log "Done. Launch Big Picture: portal-steam --gamepadui"
