dpkg-deb -x ./portal-armbian/portal-steam-bundle/libvpx6_1.8.2-1ubuntu0.4_arm64.deb /tmp/libvpx6
ln -sf "$(find /tmp/libvpx6 -name 'libvpx.so.6*' | head -1)" ~/.local/share/Steam/lib/aarch64-linux-gnu/libvpx.so.6
SDL_VIDEODRIVER=x11 GDK_BACKEND=x11 portal-steam --gamepadui
