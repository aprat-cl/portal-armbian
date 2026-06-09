#!/bin/bash
# Revert SDDM to Wayland (fixes black-screen KDE if X11 session breaks video).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash restore-portal-wayland.sh" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-aprat}"
mkdir -p /etc/sddm.conf.d /etc/environment.d /etc/xdg/plasma-workspace/env

rm -f /etc/sddm.conf.d/zz-portal-session-choice.conf
rm -f /etc/sddm.conf.d/zz-portal-gaming-x11.conf
rm -f /etc/sddm.conf.d/99-portal-gaming-x11.conf
rm -f /etc/sddm.conf.d/99-portal-x11-remote.conf

cat >/etc/sddm.conf.d/10-portal-wayland.conf << 'EOF'
[General]
DisplayServer=wayland

[Autologin]
Session=plasma
EOF

cat >/etc/sddm.conf.d/zz-portal-wayland.conf << EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
User=${STEAM_USER}
Session=plasma
Relogin=true

[Wayland]
Compositor=kwin_wayland
EOF

cat >/etc/environment.d/50-portal-wayland.conf << 'EOF'
XDG_SESSION_TYPE=wayland
GDK_BACKEND=wayland,x11
QT_QPA_PLATFORM=wayland;xcb
MOZ_ENABLE_WAYLAND=1
EOF

cat >/etc/xdg/plasma-workspace/env/portal-wayland.sh << 'EOF'
#!/bin/sh
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM=wayland;xcb
EOF
chmod 755 /etc/xdg/plasma-workspace/env/portal-wayland.sh

# Proton env must not load at KDE login (breaks taskbar on Wayland).
rm -f /etc/xdg/plasma-workspace/env/99-portal-proton.sh
if [[ -f /etc/environment.d/99-portal-proton.conf ]]; then
	cat >/etc/environment.d/99-portal-proton.conf << 'EOF'
TU_DEBUG=deck_emu
EOF
	[[ -f /usr/share/vulkan/icd.d/freedreno_icd.aarch64.json ]] && \
		echo 'VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json' \
			>> /etc/environment.d/99-portal-proton.conf
fi

echo "[OK] SDDM restored to Wayland for ${STEAM_USER}"
echo "Apply now (logs you out):  sudo systemctl restart sddm"
echo "Or reboot:  sudo reboot"
echo "Then: echo \$XDG_SESSION_TYPE  →  wayland"
