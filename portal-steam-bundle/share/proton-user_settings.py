# Portal Proton — applies to ALL games using this Proton-CachyOS ARM64 build.
# https://github.com/ValveSoftware/Proton#runtime-config-options

import os

# Marker for portal-steam updates
PORTAL_PROTON = True


def compat_config():
    return {}


def get_base_environment(env):
    """Inject DXVK/Vulkan/display env for every Proton game on Portal (SM8550)."""
    env["SDL_VIDEODRIVER"] = "x11"
    env["GDK_BACKEND"] = "x11"
    env["QT_QPA_PLATFORM"] = "xcb"
    env["TU_DEBUG"] = os.environ.get("TU_DEBUG", "deck_emu")
    if not env.get("DISPLAY") and os.path.exists("/tmp/.X11-unix/X0"):
        env["DISPLAY"] = ":0"
    icd = "/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
    if os.path.isfile(icd):
        env["VK_ICD_FILENAMES"] = icd
    return env
