#!/usr/bin/env bash
# name:     Foot
# summary:  Installs foot, a fast Wayland terminal, makes it the default with Ctrl+Alt+T, and gives it a dark, see-through look.
# default:  on
# group:    Terminal
#
# foot is in repo-oss from openSUSE itself, so it needs no extra repository, and terminfo-base carries its terminfo
# It composes dead keys itself and rings the bell through KWin, so it needs none of Ghostty's workarounds
#
# Dolphin's "Open Terminal Here" works only because foot.desktop is a plain Exec=foot without D-Bus or single instance
# The check fails loudly if a package update adds either of those
#
# The default terminal is kdeglobals [General] TerminalApplication and TerminalService, what System Settings writes
# Ctrl+Alt+T follows TerminalService, KDE's own default terminal, never a fixed app
#
# foot's .desktop has no X-KDE-Shortcuts line, so the shortcut manifest is derived from it rather than linked
# When the key does nothing after a new login, assign it once in System Settings, Shortcuts
#
# foot 1.27 names the color section [colors-dark], and keys before any header belong to [main]
# Colors are six hex digits with no #, because a # makes the line a comment, see foot.ini(5)
#
# Size 12 gives the 10x22 px cell Ghostty had, and foot rounds the cell width down, so compare row heights
# Blur needs KWin's ext-background-effect-v1, which this KWin offers
#
# The window rule forces the NothingDarkTitlebar color scheme on foot's title bar, decocolorrule 2 is Force

FOOT_CONFIG="${HOME}/.config/foot/foot.ini"

foot_launcher() {
	rpm -ql foot 2>/dev/null | grep -m1 '/share/applications/foot\.desktop$'
}

opens_in_clicked_folder() {
	local launcher
	launcher="$(foot_launcher)" || return 1
	! grep -qiE '^DBusActivatable=true|single-instance' "${launcher}"
}

report_launcher_change() {
	core::error "$(foot_launcher) now starts foot in a way that ignores the clicked folder," \
		"derive a fixed copy into ~/.local/share/applications"
	return 1
}

task() {
	want::packages foot
	want::step "foot opens in the folder it was started from" "" opens_in_clicked_folder report_launcher_change
	want::kconfig kdeglobals General TerminalApplication foot
	want::kconfig kdeglobals General TerminalService "$(basename "$(foot_launcher)" 2>/dev/null || printf foot.desktop)"
	want::global_shortcut "$(kreadconfig6 --file kdeglobals --group General --key TerminalService)" Ctrl+Alt+T

	want::ini_key "${FOOT_CONFIG}" main font "JetBrainsMono Nerd Font:size=12"
	want::ini_key "${FOOT_CONFIG}" main pad 16x8
	want::ini_key "${FOOT_CONFIG}" main initial-window-size-chars 120x36
	want::ini_key "${FOOT_CONFIG}" colors-dark background 0c0d0e
	want::ini_key "${FOOT_CONFIG}" colors-dark alpha 0.85
	want::ini_key "${FOOT_CONFIG}" colors-dark blur yes
	want::ini_key "${FOOT_CONFIG}" csd preferred server
	want::ini_key "${FOOT_CONFIG}" bell system yes
	want::ini_key "${FOOT_CONFIG}" bell urgent yes
	want::kwin_rule foot decocolor=NothingDarkTitlebar decocolorrule=2
	restart::if_changed "Ctrl+Alt+T works after the next login, or set it once in System Settings, Shortcuts"
}
