#!/usr/bin/env bash
# name:     Keep audio smooth under load
# summary:  Gives the sound server realtime priority, so audio stops crackling while the computer compiles or loads.
# default:  on
#
# PipeWire installs /usr/etc/security/limits.d/25-pw-rlimits.conf, which grants realtime priority to the pipewire group
# Creating that group and adding users is up to the distribution, per the file's own comment, and openSUSE does not
#
# Without the group PipeWire falls back to RTKit, and openSUSE polkit denies RTKit outside a session, bsc#753849
# A lingering user manager starts PipeWire at boot before anyone logs in, and no log records the denial
#
# On 2026-10-28 all cores busy for 15 seconds caused 9 audio dropouts without realtime and none with it
# pam_limits applies the group's limits when the user manager starts, so the change takes effect from the next boot

PIPEWIRE_GROUP="pipewire"

# Reads /etc/group, since id only lists the groups this login started with
user_in_pipewire_group() {
	getent group "${PIPEWIRE_GROUP}" | cut -d: -f4 | tr ',' '\n' | grep -qx "${USER}"
}

add_user_to_pipewire_group() {
	getent group "${PIPEWIRE_GROUP}" >/dev/null \
		|| core::as_root groupadd --system "${PIPEWIRE_GROUP}" || return 1
	core::as_root usermod --append --groups "${PIPEWIRE_GROUP}" "${USER}"
}

task() {
	want::packages pipewire
	want::step "Give the sound server realtime priority" sudo user_in_pipewire_group add_user_to_pipewire_group
	restart::if_changed "Audio gets realtime priority from the next boot"
}
