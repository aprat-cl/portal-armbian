#!/bin/bash
# Reset a broken Proton wine prefix ("Prefix has an invalid version").
# Run as odin2 (same user as Steam).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=portal-steam-common.sh
source "${SCRIPT_DIR}/portal-steam-common.sh"

portal_steam_init_paths
COMPAT="${STEAM_DIR}/steamapps/compatdata"

usage() {
	cat <<'HELP'
portal-reset-prefix — fix "Prefix has an invalid version" / blank game screen

  portal-reset-prefix <appid>     Delete one game's prefix (Steam recreates on launch)
  portal-reset-prefix --probe     Reset compatdata/0 (shader probe prefix; harmless)
  portal-reset-prefix --list      Show compatdata folders + prefix versions

AppID: Steam store page URL …/app/<appid>/ or game Properties → Updates.

Before deleting: back up saves from
  ~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/
(if the game does not use Steam Cloud).

Pick ONE Proton and keep it: Proton-CachyOS * ARM64 (recommended).
HELP
}

prefix_version() {
	local pfx="${1}/pfx"
	[[ -d "${pfx}" ]] || return 0
	if [[ -f "${1}/version" ]]; then
		echo -n " version=$(cat "${1}/version" 2>/dev/null)"
	fi
	if [[ -f "${pfx}/system.reg" ]]; then
		echo -n " (has pfx)"
	else
		echo -n " (empty/broken pfx)"
	fi
}

list_prefixes() {
	echo "compatdata under ${COMPAT}:"
	for d in "${COMPAT}"/*/; do
		[[ -d "${d}" ]] || continue
		id="$(basename "${d}")"
		printf "  %s%s\n" "${id}" "$(prefix_version "${d%/}")"
	done
}

reset_one() {
	local appid="$1"
	local dir="${COMPAT}/${appid}"
	if [[ ! -d "${dir}" ]]; then
		portal_steam_die "No prefix at ${dir}"
	fi
	portal_steam_log "Removing ${dir}"
	portal_steam_log "Saves (if any): ${dir}/pfx/drive_c/users/steamuser/"
	rm -rf "${dir}"
	portal_steam_log "Done. Quit Steam, relaunch, use ONE Proton, start game (prefix rebuilds ~2–5 min)."
}

[[ $# -gt 0 ]] || { usage; exit 0; }

case "$1" in
	-h | --help)
		usage
		;;
	--list)
		list_prefixes
		;;
	--probe)
		reset_one 0
		;;
	[0-9]*)
		reset_one "$1"
		;;
	*)
		portal_steam_die "Unknown appid: $1"
		;;
esac
