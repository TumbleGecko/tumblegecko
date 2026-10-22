#!/usr/bin/env bash
# name:     Heroic Games Launcher
# summary:  Installs the newest Heroic for Epic, GOG and Amazon games, starting quietly in the tray at login.
# default:  on
#
# Heroic publishes an rpm with every release, so it installs like any other package along with its menu entry
# It has no option to start hidden, so defaultSettings.startInTray in its config.json does that like its own setting
#
# An earlier version used the AppImage, whose user launcher would hide the packaged one, so both are removed

task() {
	want::github_rpm Heroic-Games-Launcher/HeroicGamesLauncher heroic '-linux-x86_64\.rpm$'
	want::absent "${HOME}/.local/share/applications/heroic.desktop"
	want::absent "${HOME}/Applications/Heroic.AppImage"
	want::json_value "${HOME}/.config/heroic/config.json" .defaultSettings.startInTray true
	want::autostart heroic.desktop
}
