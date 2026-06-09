#!/bin/bash
# Run on Portal while Megabonk is black / after a launch attempt.
APPID=3405340
STEAM="${HOME}/games/steam"

echo "=== Processes ==="
pgrep -a 'Megabonk|wine|wineserver|pressure|proton|FEX|bwrap' || echo "(none)"

echo ""
echo "=== Prefix ==="
ls -la "${STEAM}/steamapps/compatdata/${APPID}/" 2>/dev/null || echo "NO compatdata/${APPID} — prefix never created"

echo ""
echo "=== Proton logs (anywhere under Steam) ==="
find "${STEAM}" "${HOME}" -maxdepth 8 -name "steam-${APPID}.log" 2>/dev/null
find "${STEAM}" -name 'steam-*.log' 2>/dev/null | head -10

echo ""
echo "=== DXVK logs ==="
find "${STEAM}/steamapps/compatdata/${APPID}" -name '*_dxgi.log' -o -name '*_d3d11.log' 2>/dev/null

echo ""
echo "=== Steam stderr (last 40 lines) ==="
tail -40 "${STEAM}/logs/stderr.txt" 2>/dev/null || echo "no stderr.txt"
