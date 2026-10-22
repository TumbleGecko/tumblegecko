#!/usr/bin/env bash
# name:     Ctrl+Alt+Backspace restarts the desktop
# summary:  Restarts the panels and desktop when they freeze, without logging out.
# default:  on
#
# plasma-plasmashell.service is the systemd user unit that runs the shell on Plasma 6

restart_entry() {
	cat <<'ENTRY'
[Desktop Entry]
Type=Application
Name=Restart Plasma Shell
Comment=Restart the panels, desktop and system tray
Exec=systemctl --user restart plasma-plasmashell.service
Icon=plasmashell
Terminal=false
NoDisplay=true
StartupNotify=false
X-KDE-GlobalShortcutType=Service
ENTRY
}

task() {
	want::file "${HOME}/.local/share/applications/restart-plasmashell.desktop" restart_entry
	want::global_shortcut restart-plasmashell.desktop Ctrl+Alt+Backspace
	restart::if_changed "Ctrl+Alt+Backspace works after the next login, or set it once in System Settings, Shortcuts"
}
