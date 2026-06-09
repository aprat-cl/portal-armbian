#!/usr/bin/env bash
# Copy Cursor/Windows tree -> WSL ~/armbian_steamos before building.
#
# CRLF on /mnt/c breaks plain bash — use either:
#   tr -d '\r' < /mnt/c/source/armbian_steamos/sync-from-source.sh | bash
#   sh /mnt/c/source/armbian_steamos/sync-portal.sh
#
set -eu

WIN="${WIN_TREE:-/mnt/c/source/armbian_steamos}"
LINUX="${LINUX_TREE:-${HOME}/armbian_steamos}"

if [[ ! -d "${WIN}/build" ]]; then
	echo "ERROR: source not found: ${WIN}/build" >&2
	exit 1
fi

mkdir -p "${LINUX}/build/userpatches"

echo "Syncing ${WIN} -> ${LINUX}"

rsync -a --info=stats2 \
	"${WIN}/build-portal.sh" \
	"${WIN}/install-portal-steam.sh" \
	"${WIN}/sync-from-source.sh" \
	"${LINUX}/"

[[ -d "${WIN}/os/userpatches" ]] && \
	rsync -a --delete "${WIN}/os/userpatches/" "${LINUX}/build/userpatches/"

[[ -d "${WIN}/os/portal-steam" ]] && \
	rsync -a --delete "${WIN}/os/portal-steam/" "${LINUX}/os/portal-steam/"

[[ -d "${WIN}/distribution" ]] && \
	rsync -a "${WIN}/distribution/" "${LINUX}/distribution/"

rsync -a --delete \
	--exclude 'cache/' \
	--exclude 'output/' \
	--exclude '.tmp/' \
	"${WIN}/build/" "${LINUX}/build/"

for f in "${LINUX}/build-portal.sh" "${LINUX}/sync-from-source.sh" "${LINUX}/sync-portal.sh" "${LINUX}/build/compile.sh" \
	"${LINUX}/build/config/boards/ayn-odin2portal.csc" "${LINUX}/build/config/boards/ayn-odin2.csc"; do
	[[ -f "${f}" ]] || continue
	if grep -q $'\r' "${f}" 2>/dev/null; then
		tr -d '\r' < "${f}" > "${f}.lf" && mv "${f}.lf" "${f}"
	fi
done

chmod +x "${LINUX}/build-portal.sh" "${LINUX}/sync-from-source.sh" "${LINUX}/build/compile.sh" 2>/dev/null || true

echo ""
echo "Checks:"
grep -q 'User=odin2' "${LINUX}/build/config/boards/ayn-odin2portal.csc" && echo "  OK  SDDM autologin odin2 + Wayland"
grep -q 'portal_disable_usb_gadget' "${LINUX}/build/config/boards/ayn-odin2portal.csc" && echo "  OK  USB gadget disabled"
grep -q 'ayn-audio-setup' "${LINUX}/build/config/boards/ayn-odin2.csc" && echo "  OK  AYN audio setup"
[[ -f "${LINUX}/build/userpatches/firstboot.conf" ]] && echo "  OK  firstboot.conf (odin2/1234)"
echo ""
echo "Reflash build:"
echo "  rm -rf ${LINUX}/build/cache/rootfs/*"
echo "  bash ${LINUX}/build-portal.sh"
