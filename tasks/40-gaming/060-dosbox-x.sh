#!/usr/bin/env bash
# name:     DOSBox-X
# summary:  Installs DOSBox-X, where double-clicked DOS games start through gecko-run, sharp and large in their true 4:3 shape.
# default:  on
#
# DOSBox-X comes from Flathub because it publishes no Linux build of its own, and a system wide install counts
# The gecko-run task opens DOS programs in it and keeps the window open when a game fails at once
#
# output=openglnb draws with OpenGL nearest, so pixels stay sharp at any window size
# scaler "hardware2x forced" doubles every mode on the GPU, and aspect=true shows 320x200 games 4:3 like a CRT
#
# modeswitch=false stops a game's video mode change from shrinking the window back to the mode's own size
# Source is the isModeswitchSet branch in DOSBox-X src/output/output_opengl.cpp, and doublescan stays off with it
#
# The window is the largest whole multiple of 640x480 that fits the screen with room for the panel
# DOSBox-X keeps its settings in a file named after its version, so after an update the next setup run sets them again

DOSBOX=com.dosbox_x.DOSBox-X
# Pixels the panel and title bar take, so a larger window is only chosen when it really fits
SCREEN_MARGIN=160
DISPLAY_SETTINGS=("sdl output openglnb" "render aspect true" "render scaler hardware2x forced" "render modeswitch false"
	"render doublescan false" "sdl windowposition ,")

config_file() {
	local version
	version="$(flatpak info "${DOSBOX}" 2>/dev/null | awk '$1 == "Version:" { print $2 }')"
	[[ -n "${version}" ]] || return 1
	printf '%s\n' "${HOME}/.var/app/${DOSBOX}/config/dosbox-x/dosbox-x-${version}.conf"
}

# Print the largest whole multiple of 640x480 that fits the primary screen, at least 640x480
window_size() {
	local width height scale=1
	read -r width height <<< "$(kde::screen_size)"
	[[ -n "${height}" ]] || return 1
	while (( (scale + 1) * 640 <= width && (scale + 1) * 480 <= height - SCREEN_MARGIN )); do
		scale=$((scale + 1))
	done
	echo "$((scale * 640))x$((scale * 480))"
}

display_set() {
	local file setting section key value
	file="$(config_file)" || return "${CORE_EXIT_UNKNOWN}"
	for setting in "${DISPLAY_SETTINGS[@]}" "sdl windowresolution $(window_size)"; do
		read -r section key value <<< "${setting}"
		[[ "$(ini::read "${file}" "${section}" "${key}")" == "${value}" ]] || return 1
	done
}

set_display() {
	local file setting section key value
	file="$(config_file)" || return 1
	for setting in "${DISPLAY_SETTINGS[@]}" "sdl windowresolution $(window_size)"; do
		read -r section key value <<< "${setting}"
		ini::_write_key "${file}" "${section}" "${key}" "${value}" || return 1
	done
}

task() {
	want::flatpak "${DOSBOX}"
	want::step "Show DOS games sharp and large in their true shape" "" display_set set_display
}
