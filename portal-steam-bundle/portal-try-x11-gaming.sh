#!/bin/bash
# Stop forced Wayland autologin — pick Plasma (Wayland) or Plasma (X11) at SDDM login.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo portal-enable-login-choice" >&2
	exit 1
fi

echo "[portal-login] Installing Xorg + Plasma X11 session (needed for X11 option at login)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	xorg \
	xserver-xorg \
	xserver-xorg-core \
	xserver-xorg-input-libinput \
	xserver-xorg-video-all \
	xauth \
	x11-xserver-utils \
	plasma-workspace

# Drop every Portal SDDM/env override that forces Wayland or autologin.
rm -f /etc/sddm.conf.d/zz-portal-wayland.conf
rm -f /etc/sddm.conf.d/10-portal-wayland.conf
rm -f /etc/sddm.conf.d/zz-portal-gaming-x11.conf
rm -f /etc/sddm.conf.d/99-portal-gaming-x11.conf
rm -f /etc/sddm.conf.d/99-portal-x11-remote.conf
rm -f /etc/environment.d/50-portal-wayland.conf
rm -f /etc/xdg/plasma-workspace/env/portal-wayland.sh

mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/zz-portal-session-choice.conf << 'EOF'
[General]
# Greeter on X11 — session menu lists both Plasma (Wayland) and Plasma (X11).
DisplayServer=x11

[Autologin]
Relogin=false
EOF

echo ""
echo "[OK] Login screen enabled — no autologin, no forced Wayland."
echo ""
echo "Apply (logs you out):  sudo systemctl restart sddm"
echo ""
echo "At the SDDM login screen:"
echo "  1. Click your user (aprat)"
echo "  2. Open the session menu (bottom-left, desktop icon / session name)"
echo "  3. Choose:"
echo "       Plasma (Wayland)  — default Portal desktop"
echo "       Plasma (X11)      — try for Proton / AnyDesk"
echo "  4. Enter password and sign in"
echo ""
echo "After login check:  echo \$XDG_SESSION_TYPE"
echo ""
echo "Restore autologin + Wayland only:  sudo portal-restore-wayland"
