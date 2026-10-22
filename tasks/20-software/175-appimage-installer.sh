#!/usr/bin/env bash
# name:     AppImage Installer
# summary:  Installs our AppImage Installer, so double-clicking any AppImage installs it with a menu entry, and checks installed AppImages for updates.
# default:  on
# group:    Files and text
#
# Our own project at https://github.com/Hezkore/appimage-installer
# Does what its install.sh does, including its own --associate for double-clicked AppImages
#
# The program writes its own launcher and systemd units
# KDE still runs an AppImage that already has its execute bit set
# Its timer looks for updates once a day without installing them, the way install.sh sets it up

BIN="${HOME}/.local/bin"
UNITS="${HOME}/.config/systemd/user"
DESKTOP_ID=com.hezkore.appimage.installer.desktop

update_units_written() {
	[[ -f "${UNITS}/appimage-installer-update.service" && -f "${UNITS}/appimage-installer-update.timer" ]]
}

appimages_associated() {
	local type
	for type in application/vnd.appimage application/x-iso9660-appimage; do
		[[ "$(xdg-mime query default "${type}")" == "${DESKTOP_ID}" ]] || return 1
	done
}

associate_appimages() {
	"${BIN}/appimage-installer" --associate
}

write_update_units() {
	mkdir -p "${UNITS}" \
		&& "${BIN}/appimage-installer" --check-interval 24 --auto-update false --systemd-service "${UNITS}" \
		&& "${BIN}/appimage-installer" --timer-interval 4 --systemd-timer "${UNITS}"
}

task() {
	want::github_programs Hezkore/appimage-installer '-{arch}\.tar\.gz$' "${BIN}" appimage-installer
	want::step "Open double-clicked AppImages with it" "" appimages_associated associate_appimages
	want::step "Add the AppImage update check" "" update_units_written write_update_units
	want::user_unit appimage-installer-update.timer
}
