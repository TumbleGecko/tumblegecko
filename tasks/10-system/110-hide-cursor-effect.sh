#!/usr/bin/env bash
# name:     Hide the pointer while typing
# summary:  The mouse pointer disappears while you type and after a minute without moving.
# default:  on
#
# KWin's Hide Cursor effect, kwinrc [Plugins] hidecursorEnabled and its [Effect-hidecursor] settings

reload_hide_cursor() {
	kde::reconfigure_kwin && qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect hidecursor
}

task() {
	want::kconfig kwinrc Plugins hidecursorEnabled true --notify
	want::kconfig kwinrc Effect-hidecursor HideOnTyping true --notify
	want::kconfig kwinrc Effect-hidecursor InactivityDuration 60 --notify
	on_change reload_hide_cursor
}
