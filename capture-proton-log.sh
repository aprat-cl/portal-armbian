#!/bin/bash
# Force Proton logging for Megabonk (3405340). Run on Portal as your Steam user.
set -euo pipefail

APPID=3405340
STEAM="${HOME}/games/steam"
GAME="${STEAM}/steamapps/common/Megabonk/Megabonk.exe"
PROTON="${STEAM}/compatibilitytools.d/proton-cachyos-11.0-20260521-slr-arm64/proton"
LOGDIR="${HOME}/proton-debug"
COMPAT="${STEAM}/steamapps/compatdata/${APPID}"

mkdir -p "${LOGDIR}"
export STEAM_COMPAT_DATA_PATH="${COMPAT}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM}"
export PROTON_LOG=1
export PROTON_LOG_DIR="${LOGDIR}"
export WINEDEBUG=+timestamp,+tid

echo "Log dir: ${LOGDIR}"
echo "Proton:  ${PROTON}"
echo "Game:    ${GAME}"
echo ""

[[ -x "${PROTON}" ]] || { echo "Proton not found at ${PROTON}"; exit 1; }
[[ -f "${GAME}" ]] || { echo "Game not found at ${GAME}"; exit 1; }

echo "Launching (Ctrl+C to stop). Watch output + ${LOGDIR}/"
echo ""

cd "${STEAM}/steamapps/common/Megabonk"
"${PROTON}" run "${GAME}" 2>&1 | tee "${LOGDIR}/console-$(date +%Y%m%d-%H%M%S).txt"

echo ""
echo "Done. Logs:"
ls -la "${LOGDIR}/"
find "${LOGDIR}" "${COMPAT}" "${HOME}" -maxdepth 6 -name "steam-${APPID}.log" 2>/dev/null
