# lib/components/systemd.sh, system and user units

# Enable a system unit, and with --now start it as well
want::system_unit() {
	local unit="$1" now="${2:-}"
	local text="Enable ${unit}"
	[[ "${now}" == --now ]] && text="Enable and start ${unit}"
	task::requirement "${text}" sudo systemd::_system_ready systemd::_system_enable "${unit}" "${now}"
}

systemd::_system_ready() {
	local unit="$1" now="$2"
	systemctl is-enabled --quiet "${unit}" || return 1
	[[ "${now}" != --now ]] || systemctl is-active --quiet "${unit}"
}

systemd::_system_enable() {
	local unit="$1" now="$2"
	core::as_root systemctl daemon-reload || return 1
	core::as_root systemctl enable ${now:+"${now}"} "${unit}"
}

# Enable and start a user unit
want::user_unit() {
	local unit="$1"
	task::requirement "Enable and start ${unit} for this user" "" \
		systemd::_user_ready systemd::_user_enable "${unit}"
}

systemd::_user_ready() {
	systemctl --user is-enabled --quiet "$1" && systemctl --user is-active --quiet "$1"
}

systemd::_user_enable() {
	systemctl --user daemon-reload || return 1
	systemctl --user enable --now "$1"
}

# Keep a variable in the systemd user environment, so apps started from the desktop see it after the next login
# The running session gets it at once as well
want::session_variable() {
	local name="$1" value="$2" file="${3:-${HOME}/.config/environment.d/90-tumblegecko.conf}"
	task::requirement "Set ${name}=${value} for the desktop session" "" \
		systemd::_variable_set systemd::_set_variable "${name}" "${value}" "${file}"
}

systemd::_variable_set() {
	local name="$1" value="$2" file="$3"
	grep -qx "${name}=${value}" "${file}" 2>/dev/null || return 1
}

systemd::_set_variable() {
	local name="$1" value="$2" file="$3"
	mkdir -p "$(dirname "${file}")" || return 1
	touch "${file}" || return 1
	sed -i "/^${name}=/d" "${file}" || return 1
	printf '%s=%s\n' "${name}" "${value}" >> "${file}" || return 1
	systemctl --user set-environment "${name}=${value}"
}

systemd::user_unit_running() {
	systemd::_user_ready "$@"
}
