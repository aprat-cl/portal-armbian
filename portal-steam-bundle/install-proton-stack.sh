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

# Login session: every Steam/Proton child inherits DXVK/Vulkan/X11 vars.
install -d /etc/environment.d
cat > /etc/environment.d/99-portal-proton.conf << 'EOF'
# Portal Steam — Proton/DXVK/FEX (see /usr/share/portal-steam/portal-proton.env)
SDL_VIDEODRIVER=x11
GDK_BACKEND=x11
QT_QPA_PLATFORM=xcb
TU_DEBUG=deck_emu
EOF
if [[ -f /usr/share/vulkan/icd.d/freedreno_icd.aarch64.json ]]; then
	echo 'VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json' \
		>> /etc/environment.d/99-portal-proton.conf
fi

# KDE Plasma: source full env at session start (games launched from Steam inherit this).
install -d /etc/xdg/plasma-workspace/env
install -m644 "${SHARE}/portal-proton.env" /usr/share/portal-steam/portal-proton.env 2>/dev/null || \
	cp -f "${SHARE}/portal-proton.env" /usr/share/portal-steam/portal-proton.env
cat > /etc/xdg/plasma-workspace/env/99-portal-proton.sh << 'EOF'
#!/bin/sh
# shellcheck disable=SC1091
[ -r /usr/share/portal-steam/portal-proton.env ] && . /usr/share/portal-steam/portal-proton.env
EOF
chmod 755 /etc/xdg/plasma-workspace/env/99-portal-proton.sh

# Controller: uinput + gamepad udev (Steam Input / native games).
if [[ -f "${SCRIPT_DIR}/install-controller-support.sh" ]]; then
	bash "${SCRIPT_DIR}/install-controller-support.sh" "${STEAM_USER}"
elif [[ -f /usr/local/bin/portal-install-controller ]]; then
	bash /usr/local/bin/portal-install-controller "${STEAM_USER}"
fi

# Keep Wayland desktop by default (X11 caused black-screen KDE on Portal).
# Optional X11 for Proton experiments: sudo bash try-portal-x11-gaming.sh
echo "[portal-proton] Desktop stays Wayland (recommended)."
echo "  Optional X11 try: sudo bash try-portal-x11-gaming.sh"
echo "  Revert to Wayland: sudo bash restore-portal-wayland.sh"

echo ""
echo "System stack installed. As ${STEAM_USER}:"
echo "  portal-setup-games"
echo "  portal-steam --gaming          # Proton on Wayland + gamescope"
echo ""
echo "Native Linux games: disable Force Steam Play in game Properties."
echo "Controller: log out/in, then evtest. Steam → Controller → enable Steam Input."
echo "Windows-only library: Steam Settings → Compatibility → Proton-CachyOS ARM64."
