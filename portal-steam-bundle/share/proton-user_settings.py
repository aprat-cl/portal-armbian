# Portal Proton — env overrides for every game using Proton-CachyOS ARM64 on Portal.
# Proton reads the user_settings dict below (not compat_config / get_base_environment).
# https://github.com/ValveSoftware/Proton/blob/proton_11.0/user_settings.sample.py

user_settings = {
	# ROCKNIX/Portal: Proton presents via XWayland on KDE Wayland.
	"SDL_VIDEODRIVER": "x11",
	"GDK_BACKEND": "x11",
	"QT_QPA_PLATFORM": "xcb",
	# Adreno turnip + DXVK on SM8550.
	"TU_DEBUG": "deck_emu",
	"VK_ICD_FILENAMES": "/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json",
}
