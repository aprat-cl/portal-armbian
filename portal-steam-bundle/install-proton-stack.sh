#!/bin/bash
# System-wide Proton/FEX/DXVK stack for ALL Steam games (run once with sudo).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-proton-stack.sh" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE="${SCRIPT_DIR}/share"
[[ -f "${SHARE}/portal-proton.env" ]] || SHARE="/usr/share/portal-steam"

STEAM_USER="${SUDO_USER:-odin2}"
STEAM_HOME="$(getent passwd "${STEAM_USER}" | cut -d: -f6)"

echo "[portal-proton] Installing system Proton stack for user ${STEAM_USER}..."

apt-get update
apt-get install -y \
	gamescope mesa-vulkan-drivers vulkan-tools libvulkan1 \
	squashfs-tools squashfuse xterm

# pressure-vessel / Proton container (AArch64 Ubuntu lacks this symlink).
if [[ ! -e /usr/lib64 ]] && [[ -d /usr/lib/aarch64-linux-gnu ]]; then
	ln -sfn /usr/lib/aarch64-linux-gnu /usr/lib64
	echo "[portal-proton] /usr/lib64 → aarch64-linux-gnu"
fi

# Vulkan/turnip only at login — do NOT force GDK/Qt/SDL to X11 (breaks KDE panel on Wayland).
install -d /etc/environment.d
cat > /etc/environment.d/99-portal-proton.conf << 'EOF'
# Portal Steam — Vulkan for desktop apps. Proton/X11 vars: portal-steam only.
TU_DEBUG=deck_emu
EOF
if [[ -f /usr/share/vulkan/icd.d/freedreno_icd.aarch64.json ]]; then
	echo 'VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json' \
		>> /etc/environment.d/99-portal-proton.conf
fi

install -m644 "${SHARE}/portal-proton.env" /usr/share/portal-steam/portal-proton.env 2>/dev/null || \
	cp -f "${SHARE}/portal-proton.env" /usr/share/portal-steam/portal-proton.env
# Do not source portal-proton.env at Plasma login — portal-steam / portal-game-launch do that for games.
rm -f /etc/xdg/plasma-workspace/env/99-portal-proton.sh

# Default desktop stays Wayland unless you pick X11 at SDDM login.
echo "[portal-proton] Proton env installed. Session type unchanged until you pick at login."
echo "  Pick Wayland/X11 at login: sudo portal-enable-login-choice && sudo systemctl restart sddm"
echo "  Autologin + Wayland again: sudo portal-restore-wayland"

echo ""
echo "System stack installed. As ${STEAM_USER}:"
echo "  portal-setup-games"
echo "  portal-steam --gaming          # Proton on Wayland + gamescope"
echo ""
echo "Native Linux games: disable Force Steam Play in game Properties."
echo "Windows-only library: Steam Settings → Compatibility → Proton-CachyOS ARM64."
