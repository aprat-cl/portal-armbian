#!/bin/bash
# Steam + native game controller support on Portal (uinput, gamepad permissions).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run: sudo bash install-controller-support.sh" >&2
	exit 1
fi

STEAM_USER="${SUDO_USER:-${1:-aprat}}"
[[ -n "$(getent passwd "${STEAM_USER}" 2>/dev/null)" ]] || {
	echo "User ${STEAM_USER} not found. Usage: sudo bash install-controller-support.sh [user]" >&2
	exit 1
}

echo "[portal-controller] Setting up for user ${STEAM_USER}..."

apt-get update
apt-get install -y evtest joystick python3-evdev 2>/dev/null || \
	apt-get install -y evtest joystick

# Steam virtual gamepad (Big Picture layout) needs uinput — your logs showed this failing.
modprobe uinput 2>/dev/null || true
grep -qx uinput /etc/modules 2>/dev/null || echo uinput >> /etc/modules

cat >/etc/udev/rules.d/99-portal-uinput.rules << 'EOF'
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
EOF

# Built-in Portal / Odin2 gamepad (from ayn-odin2.csc; widen for Portal Pro names).
cat >/etc/udev/rules.d/99-portal-gamepad.rules << 'EOF'
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="AYN Odin2 Gamepad", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="AYN Odin 2 Gamepad", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="AYN Odin2 Portal Gamepad", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
EOF

usermod -aG input "${STEAM_USER}" 2>/dev/null || true

udevadm control --reload-rules
udevadm trigger

echo ""
echo "Controller stack installed."
echo "  Log out and back in (or reboot) so group 'input' applies to ${STEAM_USER}."
echo ""
echo "Verify built-in pad:"
echo "  evtest   # pick AYN / gamepad event device, press buttons"
echo "  ls /dev/input/by-id/*joystick* /dev/input/by-id/*event* 2>/dev/null"
echo ""
echo "In Steam (Big Picture):"
echo "  Settings → Controller → enable Steam Input + Generic Gamepad"
echo "  For native Linux games: Properties → uncheck 'Force Steam Play' if enabled"
