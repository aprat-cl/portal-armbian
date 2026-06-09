#!/bin/bash
# FEX for Proton/x86 game binaries. Steam UI stays native (portal-steam).

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo portal-install-fex" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y software-properties-common curl python3 \
	mesa-vulkan-drivers vulkan-tools libvulkan1

curl --silent https://raw.githubusercontent.com/FEX-Emu/FEX/main/Scripts/InstallFEX.py | python3

echo ""
echo "[portal-install-fex] FEX installed. As odin2 run:"
echo "  portal-setup-games"
echo "  portal-steam --gamepadui"
