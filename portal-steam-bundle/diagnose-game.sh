#!/bin/bash
# Collect Portal Steam / Proton / FEX state while debugging blank-game screens.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=portal-steam-common.sh
source "${SCRIPT_DIR}/portal-steam-common.sh"

portal_steam_init_paths
export HOME="${STEAM_HOME}"

section() { echo ""; echo "=== $* ==="; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; }

section "Session"
echo "USER=${STEAM_USER} HOME=${STEAM_HOME}"
echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset} DISPLAY=${DISPLAY:-unset}"
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"

section "FEX"
if command -v FEX >/dev/null 2>&1; then
	if out="$(FEX /usr/bin/uname -m 2>&1)"; then
		[[ "${out}" == *x86_64* ]] && ok "FEX uname -m → x86_64" || warn "FEX uname: ${out}"
	else
		fail "FEX uname failed"
	fi
else
	fail "FEX not in PATH"
fi
if [[ -f "${HOME}/.config/fex-emu/Config.json" ]]; then
	grep -E 'RootFS|Vulkan' "${HOME}/.config/fex-emu/Config.json" || true
fi

section "binfmt (x86 for game PE binaries)"
if [[ -f /proc/sys/fs/binfmt_misc/x86_64 ]]; then
	echo "x86_64: $(cat /proc/sys/fs/binfmt_misc/x86_64 2>/dev/null || echo missing)"
else
	warn "x86_64 binfmt not registered"
fi

section "Vulkan (host / Adreno)"
if command -v vulkaninfo >/dev/null 2>&1; then
	vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|deviceType|apiVersion' | head -5 || \
		fail "vulkaninfo failed — install mesa-vulkan-drivers vulkan-tools"
else
	warn "vulkaninfo not installed"
fi
echo "VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-default}"

section "Steam / Proton"
[[ -x "${STEAM_CLIENT}" ]] && ok "Client: ${STEAM_CLIENT}" || fail "Steam client missing"
[[ -d "${PROTON_DIR}" ]] && ok "Proton: ${PROTON_DIR}" || warn "Proton 11 ARM64 dir missing"
ls -1 "${STEAM_DIR}/compatibilitytools.d/" 2>/dev/null | head -10 || true

section "pressure-vessel prerequisites"
[[ -e /usr/lib64 ]] && ok "/usr/lib64 exists" || \
	warn "Missing /usr/lib64 — run: sudo ln -sf /usr/lib/aarch64-linux-gnu /usr/lib64"

section "Running game-related processes (run while game is black)"
pgrep -a 'steam|pressure|proton|wine|FEX|fex|gamescope|Megabonk|dxvk|bwrap|reaper' 2>/dev/null || \
	echo "(none — if game 'running' but empty: stuck before wine, or hung after launch)"

section "Recent Steam stderr"
stderr="${STEAM_DIR}/logs/stderr.txt"
if [[ -f "${stderr}" ]]; then
	if grep -q 'invalid version' "${stderr}" 2>/dev/null; then
		fail "Proton prefix version mismatch — game will not run (blank screen)"
		grep 'invalid version\|Upgrading prefix' "${stderr}" | tail -5 || true
		echo "  Fix: portal-reset-prefix <appid>   then relaunch with ONE Proton (CachyOS ARM64)"
	fi
	tail -30 "${stderr}"
else
	warn "No ${stderr}"
fi

section "Proton prefixes (compatdata)"
portal-reset-prefix --list 2>/dev/null || {
	for d in "${STEAM_DIR}/steamapps/compatdata"/*/; do
		[[ -d "${d}" ]] && echo "  $(basename "${d}")"
	done
}

section "Proton log (newest)"
proton_log="$(find "${STEAM_DIR}/steamapps/compatdata" -name 'steam-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
if [[ -n "${proton_log}" && -f "${proton_log}" ]]; then
	echo "${proton_log}"
	tail -40 "${proton_log}"
else
	warn "No PROTON_LOG yet — set Launch Options: PROTON_LOG=1 %command%"
fi

section "DXVK logs (DX11 games — look for empty = DXVK never inited)"
find "${STEAM_DIR}/steamapps/compatdata" \( -name '*_dxgi.log' -o -name '*_d3d11.log' \) \
	-printf '%T@ %p\n' 2>/dev/null | sort -rn | head -3 | cut -d' ' -f2- | while read -r f; do
	echo "--- ${f} ---"
	tail -15 "${f}" 2>/dev/null || true
done

section "What to try (Steam → game → Properties → Launch Options)"
cat <<'OPTS'

DX11 (Megabonk, Unity): Proton → DXVK → Vulkan (turnip). Not a "wrong Proton" pick
unless you chose stable amd64 Proton — use Proton 11 / Proton-CachyOS ARM64 only.

1) Adreno + DXVK debug (ROCKNIX turnip trick for GPU checks):
   TU_DEBUG=deck_emu DXVK_HUD=fps PROTON_LOG=1 %command%

2) gamescope wrapper:
   portal-game-launch %command%

3) Windowed:
   %command% -windowed

4) pressure-vessel shell (stuck before game exe):
   PRESSURE_VESSEL_SHELL=instead %command%

5) While black: pgrep -a wine|proton|dxvk
   wine+no DXVK HUD → Vulkan/DXVK init failed (check *_dxgi.log above).
   no wine → pressure-vessel / prefix still building.

OPTS
