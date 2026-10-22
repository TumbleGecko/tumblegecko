#!/usr/bin/env bash
# name:     Keep the desktop session alive
# summary:  Lets the session bus and Plasma keep enough files open, so the desktop stops logging you out under load.
# default:  on
#
# The user dbus-broker unit sets no LimitNOFILE, so it inherits a soft limit of 1024, while the system bus gets 16384
# At that limit the broker exits, kwin_wayland and plasmashell abort with it, and the session ends, seen 2026-06-24
#
# plasmashell hit the same limit on its own with "QProcess: Cannot create pipe (Too many open files)"
# The user manager's hard limit is 524288, so a user drop-in can raise the soft limit without root

SYSTEMD_USER="${HOME}/.config/systemd/user"

file_limit_dropin() {
	cat <<'DROPIN'
# TumbleGecko raises the open file limit so a busy session does not end
[Service]
LimitNOFILE=524288
DROPIN
}

task() {
	want::file "${SYSTEMD_USER}/dbus-broker.service.d/nofile.conf" file_limit_dropin \
		--then "systemctl --user daemon-reload"
	want::file "${SYSTEMD_USER}/plasma-plasmashell.service.d/nofile.conf" file_limit_dropin \
		--then "systemctl --user daemon-reload"
	restart::if_changed "The new limit applies from the next login"
}
