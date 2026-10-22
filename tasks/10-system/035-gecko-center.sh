#!/usr/bin/env bash
# name:     Gecko Center
# summary:  Installs Gecko Center, the heart of this setup for updates, apps, health, snapshots, drivers and help, and quietly checks for updates once a week.
# default:  on
#
# Gecko Center is our own project at https://github.com/TumbleGecko/gecko-center, followed at its newest main commit
# It replaces Discover, which the safe updates task removes, and opens .rpm files and Flathub links
#
# Its own --install writes the launcher, the System Settings entry, the file and link defaults and the tray unit
# so they live in one place
# Its weekly check is a user timer plus one system unit that only refreshes, which a polkit rule lets you start
#
# The polkit rule can only be read as root, so the check looks at the system unit installed beside it
# Its Journal page reads the system journal, which members of systemd-journal may read without a password
# https://www.freedesktop.org/software/systemd/man/latest/journalctl.html#Description

SOURCE="${HOME}/.local/share/tumblegecko/sources/gecko-center"
LINK_TYPES=(application/x-rpm application/vnd.flatpak.ref x-scheme-handler/flatpak+https x-scheme-handler/appstream)

installed_and_current() {
	local type
	[[ -f "${HOME}/.local/share/applications/gecko-center.desktop" ]] || return 1
	grep -q "${SOURCE}" "${HOME}/.local/share/applications/gecko-center.desktop" || return 1
	grep -q "${SOURCE}" "${HOME}/.local/share/plasma/systemsettings/externalmodules/gecko-center.desktop" || return 1
	for type in "${LINK_TYPES[@]}"; do
		[[ "$(xdg-mime query default "${type}")" == gecko-center.desktop ]] || return 1
	done
	systemctl --user is-enabled --quiet gecko-center-tray.service || return 1
	grep -q "${SOURCE}" "${HOME}/.config/systemd/user/gecko-center-tray.service"
}

install_gecko_center() {
	"${SOURCE}/gecko-center.sh" --install
}

weekly_check_installed() {
	[[ -f /etc/systemd/system/gecko-center-refresh.service ]] \
		&& systemctl --user is-enabled --quiet gecko-center-check.timer
}

install_weekly_check() {
	"${SOURCE}/gecko-center.sh" --install-timer weekly
}

# The group file is read rather than id, since a new membership only reaches running programs after logging in again
reads_system_journal() {
	getent group systemd-journal | cut -d: -f4 | tr ',' '\n' | grep -qx "${USER}"
}

let_read_system_journal() {
	core::as_root usermod --append --groups systemd-journal "${USER}"
}

task() {
	want::packages --no-recommends python3-pyside6 ibm-plex-sans-fonts dejavu-fonts flatpak libnotify-tools
	want::git_branch https://github.com/TumbleGecko/gecko-center.git main "${SOURCE}"
	want::step \
		"Install Gecko Center with its tray icon and System Settings entry, open .rpm files and Flathub links with it" "" \
		installed_and_current install_gecko_center
	want::step "Check for updates once a week" sudo weekly_check_installed install_weekly_check
	want::step "Let Journal show the system's messages without a password" sudo reads_system_journal \
		let_read_system_journal
}
