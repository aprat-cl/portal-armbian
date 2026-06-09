dpkg-deb -x ./portal-armbian/portal-steam-bundle/libvpx-dev_1.8.2-1build1_arm64.deb /tmp/libvpx-dev
ln -sf "$(find /tmp/libvpx-dev -name 'libvpx.so.6*' | head -1)" ~/.local/share/Steam/lib/aarch64-linux-gnu/libvpx.so.6
SDL_VIDEODRIVER=x11 GDK_BACKEND=x11 portal-steam --gamepadui
