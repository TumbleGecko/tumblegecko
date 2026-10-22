#!/usr/bin/env bash
# name:     MangoHud
# summary:  Installs MangoHud, a small FPS and frame time overlay for every game, hidden until you press Ctrl+Alt+Z.
# default:  on
#
# MANGOHUD=1 for the whole session arms MangoHud's implicit Vulkan layer in every client
# Source is enable_environment in /usr/share/vulkan/implicit_layer.d/MangoHud.x86_64.json
#
# It starts hidden because no_display is set, and toggle_hud shows it for the rest of that game
# MANGOHUD_CONFIG must stay unset, because MangoHud ignores MangoHud.conf whenever it is set
#
# No frame rate limit here, capping is done per game through DXVK
# The 32 bit package covers 32 bit games under Wine

MANGOHUD_DIRECTORY="${HOME}/.config/MangoHud"

mangohud_conf() {
	cat <<'CONF'
# TumbleGecko: FPS and frame times only, hidden until Ctrl+Alt+Z
legacy_layout=0
position=top-left
font_size=20
background_alpha=0.4
round_corners=6
table_columns=3

fps
frametime
frame_timing=1
cpu_stats=0
gpu_stats=0

no_display=1
toggle_hud=Control_L+Alt_L+z

# Vulkan programs that never get the overlay, comma separated executable names
blacklist=
CONF
}

task() {
	want::packages --no-recommends mangohud mangohud-32bit
	want::session_variable MANGOHUD 1 "${HOME}/.config/environment.d/95-mangohud.conf"
	want::file "${MANGOHUD_DIRECTORY}/MangoHud.conf" mangohud_conf
	want::absent "${MANGOHUD_DIRECTORY}/presets.conf"
	restart::if_changed "Games started from a launcher such as Steam get the overlay once that launcher restarts"
}
