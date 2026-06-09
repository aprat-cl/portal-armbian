#!/bin/bash
# Optional: install FEX for x86 Windows games via Proton (not for the Steam client).
# Steam itself always runs native aarch64 via portal-steam.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo portal-install-fex" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y software-properties-common curl python3
curl --silent https://raw.githubusercontent.com/FEX-Emu/FEX/main/Scripts/InstallFEX.py | python3

echo "[portal-install-fex] Done. Steam stays native: use portal-steam (not the steam command in PATH)."
