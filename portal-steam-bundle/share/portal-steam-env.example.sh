# Copy to ~/.config/portal-steam/env.sh and edit. Sourced by portal-steam / portal-game-launch.
#
# DX11 games (Megabonk, most Unity/Unreal): Proton uses DXVK → Vulkan (turnip/freedreno).
# PROTON_USE_WINED3D does NOT help DX11 — it only tests OpenGL (DX9-era path).
#
# export PROTON_LOG=1
# export DXVK_HUD=fps
# export TU_DEBUG=deck_emu
# export MESA_VK_WSI_PRESENT_MODE=immediate
