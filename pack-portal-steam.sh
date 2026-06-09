#!/usr/bin/env bash
# Build a self-contained folder + tarball to copy to the Portal (USB, scp, etc.).
# Does not require the full armbian build tree on the device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/os/portal-steam"
OUT="${SCRIPT_DIR}/portal-steam-bundle"
ARCHIVE="${SCRIPT_DIR}/portal-steam-bundle.tar.gz"

if [[ ! -f "${SRC}/portal-steam" ]]; then
	echo "ERROR: ${SRC}/portal-steam not found." >&2
	exit 1
fi

rm -rf "${OUT}"
mkdir -p "${OUT}"

cp "${SCRIPT_DIR}/install-portal-steam.sh" "${OUT}/"
cp "${SRC}/portal-steam" "${SRC}/install-steam.sh" "${SRC}/portal-steam-common.sh" \
	"${SRC}/install-fex.sh" "${SRC}/setup-games.sh" "${SRC}/install-proton-stack.sh" \
	"${SRC}/install-controller-support.sh" "${SRC}/restore-portal-wayland.sh" \
	"${SRC}/try-portal-x11-gaming.sh" \
	"${SRC}/portal-game-launch" "${SRC}/diagnose-game.sh" "${SRC}/reset-prefix.sh" "${OUT}/"
cp -a "${SRC}/share" "${OUT}/"

chmod 755 "${OUT}/install-portal-steam.sh" "${OUT}/portal-steam" "${OUT}/install-steam.sh" \
	"${OUT}/portal-steam-common.sh" "${OUT}/install-fex.sh" "${OUT}/setup-games.sh" \
	"${OUT}/install-proton-stack.sh" \
	"${OUT}/portal-game-launch" "${OUT}/diagnose-game.sh" "${OUT}/reset-prefix.sh"

tar -czf "${ARCHIVE}" -C "${SCRIPT_DIR}" portal-steam-bundle

echo "Created:"
echo "  ${OUT}/"
echo "  ${ARCHIVE}"
echo ""
echo "Copy to Portal (pick one):"
echo "  scp ${ARCHIVE} odin2@<portal-ip>:~/"
echo "  # or copy the folder via USB"
echo ""
echo "On device:"
echo "  tar xzf portal-steam-bundle.tar.gz"
echo "  cd portal-steam-bundle"
echo "  sudo bash install-portal-steam.sh"
echo "  portal-install-steam          # as odin2"
echo "  sudo bash install-proton-stack.sh  # once — Proton env for all games"
echo "  portal-setup-games"
echo "  portal-steam --gaming"
