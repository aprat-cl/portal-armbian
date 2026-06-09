#!/bin/bash
# Fix missing KDE panel / broken desktop after Proton env or X11 session experiments.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo portal-fix-desktop" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-aprat}"

echo "[portal-desktop] Removing Proton vars from KDE login (they break the taskbar on Wayland)..."

# These force Qt/GTK to X11 and break plasmashell on Wayland sessions.
rm -f /etc/xdg/plasma-workspace/env/99-portal-proton.sh

if [[ -f /etc/environment.d/99-portal-proton.conf ]]; then
	cat >/etc/environment.d/99-portal-proton.conf << 'EOF'
# Portal Steam — Vulkan only at login. Game/X11 vars come from portal-steam, not the desktop.
TU_DEBUG=deck_emu
EOF
	if [[ -f /usr/share/vulkan/icd.d/freedreno_icd.aarch64.json ]]; then
		echo 'VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json' \
			>> /etc/environment.d/99-portal-proton.conf
	fi
fi

# Restore Wayland session defaults if login-choice removed them.
if [[ ! -f /etc/environment.d/50-portal-wayland.conf ]]; then
	cat >/etc/environment.d/50-portal-wayland.conf << 'EOF'
XDG_SESSION_TYPE=wayland
GDK_BACKEND=wayland,x11
QT_QPA_PLATFORM=wayland;xcb
MOZ_ENABLE_WAYLAND=1
EOF
fi

if [[ ! -f /etc/xdg/plasma-workspace/env/portal-wayland.sh ]]; then
	cat >/etc/xdg/plasma-workspace/env/portal-wayland.sh << 'EOF'
#!/bin/sh
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM=wayland;xcb
EOF
	chmod 755 /etc/xdg/plasma-workspace/env/portal-wayland.sh
fi

echo ""
echo "[OK] Desktop env restored for ${STEAM_USER}."
echo ""
echo "Log out and back in (pick Plasma Wayland at login), or run:"
echo "  sudo systemctl restart sddm"
echo ""
echo "If panel still missing AFTER Wayland login, as ${STEAM_USER}:"
echo "  plasmashell --replace &"
echo "Or reset panel layout:"
echo "  mv ~/.config/plasma-org.kde.plasma.desktop-appletsrc{,.bak}; plasmashell --replace &"
