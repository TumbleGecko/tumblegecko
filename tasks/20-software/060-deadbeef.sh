#!/usr/bin/env bash
# name:     DeaDBeeF
# summary:  Installs DeaDBeeF and opens music in it, starting centered on screen and then remembering where you put it.
# default:  on
# group:    Audio software
#
# The types are what deadbeef.desktop declares plus common ones it plays but does not list
# DeaDBeeF rewrites its config when it quits, so its status bar setting is only changed while it is closed
#
# Its config is "key value" lines rather than INI, and the window class is plain deadbeef
# positionrule 4 is Remember, so the centered position only applies the first time

MUSIC_TYPES=(application/ogg audio/x-vorbis+ogg application/x-ogg audio/mp3 audio/prs.sid audio/x-flac audio/mpeg
	audio/x-mpeg audio/x-mod audio/x-it audio/x-s3m audio/x-xm audio/x-mpegurl audio/x-scpls application/x-cue audio/m4a
	audio/wav audio/x-wav audio/ogg audio/opus audio/x-opus+ogg audio/aac audio/mp4 audio/x-aiff audio/aiff
	audio/x-musepack
	audio/x-ape audio/x-tta audio/flac audio/midi audio/x-wavpack)
DEADBEEF_CONFIG="${HOME}/.config/deadbeef/config"

status_bar_hidden() {
	grep -qx 'gtkui.statusbar.visible 0' "${DEADBEEF_CONFIG}" 2>/dev/null
}

hide_status_bar() {
	if pgrep -u "$(id -u)" -x deadbeef >/dev/null; then
		core::error "DeaDBeeF is running and would overwrite its config when it quits, close it and run this again"
		return 1
	fi
	mkdir -p "$(dirname "${DEADBEEF_CONFIG}")" && touch "${DEADBEEF_CONFIG}" || return 1
	sed -i '/^gtkui\.statusbar\.visible /d' "${DEADBEEF_CONFIG}" \
		&& printf 'gtkui.statusbar.visible 0\n' >> "${DEADBEEF_CONFIG}"
}

task() {
	want::packages --no-recommends deadbeef
	want::mime_default deadbeef.desktop "${MUSIC_TYPES[@]}"
	want::step "Hide DeaDBeeF's status bar" "" status_bar_hidden hide_status_bar
	want::kwin_rule deadbeef positionrule=4 position:=centered:800x500
}
