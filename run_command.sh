pgrep -a 'Megabonk|wine|wineserver'
find ~/games/steam/steamapps/compatdata/3405340 -name 'steam-*.log' -printf '%T@ %p\n' | sort -rn | head -1
tail -100 <that-file>
find ~/games/steam/steamapps/compatdata/3405340 -name '*_dxgi.log' -exec tail -30 {} \;

