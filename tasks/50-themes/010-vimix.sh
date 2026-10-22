#!/usr/bin/env bash
# name:     Vimix
# summary:  Installs the newest Vimix icon theme, light and dark, and fills in Telegram's tray icons so its unread badge shows.
# default:  on
#
# Vimix publishes no releases, so its master branch is the newest version, installed with its own install.sh
# Both variants are installed, and the Nothing theme task uses Vimix-dark
#
# Telegram asks the tray for org.telegram.desktop-attention-symbolic, which Vimix lacks
# So KDE strips the name down to Vimix's colored icon and the unread state never shows
#
# breeze-icons has proper symbolic tray icons, which are copied in and checked on their own
# install.sh rewrites the theme folders and drops them, so a reinstall copies them again
#
# KDE's icon cache in ~/.cache/icon-cache.kcache still points at replaced files after a reinstall
# So it is removed and KDE builds it again

ICONS="${HOME}/.local/share/icons"
SOURCE="${HOME}/.local/share/tumblegecko/sources/vimix-icon-theme"
TELEGRAM_TRAY_ICONS=(org.telegram.desktop-symbolic org.telegram.desktop-attention-symbolic
	org.telegram.desktop-mute-symbolic)

theme_matches_source() {
	[[ -d "${ICONS}/Vimix-dark" ]] \
		&& cmp -s "${SOURCE}/.tumblegecko-commit" "${ICONS}/Vimix-dark/.tumblegecko-commit" || return 1
}

install_theme() {
	(cd "${SOURCE}" && ./install.sh -d "${ICONS}") && cp "${SOURCE}/.tumblegecko-commit" "${ICONS}/Vimix-dark/"
}

tray_icons_present() {
	local name
	for name in "${TELEGRAM_TRAY_ICONS[@]}"; do
		grep -q ColorScheme "${ICONS}/Vimix/scalable/apps/${name}.svg" 2>/dev/null || return 1
	done
}

copy_tray_icons() {
	local breeze name
	breeze="$(dirname "$(find /usr/share/icons/breeze -name 'org.telegram.desktop-attention-symbolic.svg' | head -1)")"
	for name in "${TELEGRAM_TRAY_ICONS[@]}"; do
		install -D -m 0644 "$(readlink -f "${breeze}/${name}.svg")" "${ICONS}/Vimix/scalable/apps/${name}.svg" \
			|| return 1
	done
}

task() {
	want::git_branch https://github.com/vinceliuice/vimix-icon-theme.git master "${SOURCE}"
	want::step "Install the Vimix icon theme" "" theme_matches_source install_theme
	want::step "Add Telegram's tray icons to Vimix" "" tray_icons_present copy_tray_icons
	on_change rm -f "${HOME}/.cache/icon-cache.kcache"
	restart::if_changed "Icons look right again in apps started after this, restart Dolphin and Plasma for the rest"
}
