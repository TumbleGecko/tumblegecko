#!/usr/bin/env bash
# name:     Clean desktop
# summary:  Clears the default Home and Trash icons off the desktop and uses medium sized desktop icons.
# default:  on
#
# Folder View's iconSize slider maps 0 to 6 onto 22, 32, 48, 64, 96, 128 and 256 px, so 3 is the middle at 64 px
# Source /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/code/FolderTools.js
#
# The desktop's containment number differs between installs, so it is looked up by its plugin

APPLETS=plasma-org.kde.plasma.desktop-appletsrc
MEDIUM_ICONS=3

# Print the containment number of every desktop Folder View, one per screen
desktop_containments() {
	awk '
		/^\[Containments\]\[[0-9]+\]$/ { id = $0; gsub(/[^0-9]/, "", id); root = 1; next }
		/^\[/ { root = 0 }
		root && $0 == "plugin=org.kde.plasma.folder" { print id }
	' "${HOME}/.config/${APPLETS}" 2>/dev/null
}

icons_medium() {
	local containment found=0
	while IFS= read -r containment; do
		found=1
		[[ "$(kreadconfig6 --file "${APPLETS}" --group Containments --group "${containment}" --group General \
			--key iconSize)" == "${MEDIUM_ICONS}" ]] || return 1
	done < <(desktop_containments)
	(( found ))
}

make_icons_medium() {
	local containment
	while IFS= read -r containment; do
		kwriteconfig6 --file "${APPLETS}" --group Containments --group "${containment}" --group General \
			--key iconSize "${MEDIUM_ICONS}" || return 1
	done < <(desktop_containments)
}

desktop_has_no_launchers() {
	[[ -z "$(find "${HOME}/Desktop" -maxdepth 1 -type f -name '*.desktop' 2>/dev/null)" ]]
}

remove_desktop_launchers() {
	find "${HOME}/Desktop" -maxdepth 1 -type f -name '*.desktop' -delete
}

restart_plasmashell() {
	systemctl --user restart plasma-plasmashell.service
}

task() {
	want::step "Remove the default launchers from ~/Desktop" "" desktop_has_no_launchers remove_desktop_launchers
	want::step "Use medium desktop icons" "" icons_medium make_icons_medium
	on_change restart_plasmashell
}
