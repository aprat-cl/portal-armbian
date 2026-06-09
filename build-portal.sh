#!/usr/bin/env bash
# Ayn Odin 2 Portal Pro — reflash image with all Portal fixes baked in.
#
# Included in image:
#   - Login: odin2 / 1234 (root: 1234)
#   - KDE Plasma on Wayland (SDDM + plasma-workspace-wayland)
#   - PipeWire + AYN UCM audio (AYN-Odin2) + ayn-audio-setup service
#   - armbian-firmware-full (qcom/sm8550/ayn/odin2portal blobs)
#   - USB gadget RNDIS OFF (keyboard/mouse on Type-C work)
#   - X11 fallback: rename on SD .../zz-portal-x11.conf.disabled -> zz-portal-x11.conf
#   - Steam layer (portal-steam extension): gamescope + portal-install-steam on first boot
#
# WSL workflow (CRLF-safe sync from /mnt/c):
#   tr -d '\r' < /mnt/c/source/armbian_steamos/sync-from-source.sh | bash
#   rm -rf ~/armbian_steamos/build/cache/rootfs/*
#   bash ~/armbian_steamos/build-portal.sh
#
# Flash output .img from ~/armbian_steamos/build/output/images/ with Balena Etcher.
# Boot: Vol Up + Power. First boot runs wizard with presets (mostly Enter through).
#
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${SCRIPT_DIR}" in
	/mnt/*|/mnt/c/*)
		echo "ERROR: do not build on ${SCRIPT_DIR}" >&2
		echo "  bash /mnt/c/source/armbian_steamos/sync-from-source.sh" >&2
		echo "  bash ~/armbian_steamos/build-portal.sh" >&2
		exit 1
		;;
esac

if [[ ! -f "${SCRIPT_DIR}/build/compile.sh" ]]; then
	echo "ERROR: ${SCRIPT_DIR}/build/compile.sh not found." >&2
	exit 1
fi

cd "${SCRIPT_DIR}/build"

export PESTER_TERMINAL=no
export DOCKER_USE_HOST_DNS=no

exec ./compile.sh \
	BOARD=ayn-odin2portal \
	BRANCH=edge \
	RELEASE=noble \
	BUILD_DESKTOP=yes \
	BUILD_MINIMAL=no \
	DESKTOP_ENVIRONMENT=kde-plasma \
	DESKTOP_TIER=minimal \
	ENABLE_EXTENSIONS=portal-steam \
	"$@"
