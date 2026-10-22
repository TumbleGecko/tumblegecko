# lib/preconditions.sh, what a machine must be before TumbleGecko changes anything
#
# There is one target, openSUSE Tumbleweed with KDE Plasma 6 on Wayland, a btrfs root and exactly one GPU
# Anything else is refused with a clear reason rather than half supported

# Print one precondition event and return whether it passed
preconditions::_report() {
	local name="$1" passed="$2" detail="$3" fix="${4:-}"
	core::event precondition name="${name}" ok:="${passed}" detail="${detail}" fix="${fix}"
	[[ "${passed}" == true ]]
}

preconditions::_distribution() {
	local id="" pretty=""
	if [[ -r /etc/os-release ]]; then
		id="$(. /etc/os-release && printf '%s' "${ID:-}")"
		pretty="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-}")"
	fi
	if [[ "${id}" == opensuse-tumbleweed ]]; then
		preconditions::_report Distribution true "${pretty}"
	else
		preconditions::_report Distribution false \
			"Found ${pretty:-an unknown system}, TumbleGecko needs openSUSE Tumbleweed"
	fi
}

preconditions::_desktop() {
	local version=""
	if [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] && command -v plasmashell >/dev/null; then
		version="$(plasmashell --version 2>/dev/null | awk '{ print $2 }')"
	fi
	if [[ "${version}" == 6.* ]]; then
		preconditions::_report Desktop true "KDE Plasma ${version}"
	else
		preconditions::_report Desktop false "TumbleGecko needs a KDE Plasma 6 desktop"
	fi
}

# systemd-logind sets XDG_SESSION_TYPE for the active session
preconditions::_session() {
	if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
		preconditions::_report Session true Wayland
	else
		preconditions::_report Session false \
			"This is a ${XDG_SESSION_TYPE:-unknown} session, TumbleGecko needs Wayland" session
	fi
}

preconditions::_filesystem() {
	local filesystem
	filesystem="$(findmnt -n -o FSTYPE / 2>/dev/null)"
	if [[ "${filesystem}" == btrfs ]]; then
		preconditions::_report Filesystem true "btrfs, so snapshots can roll back a bad change"
	else
		preconditions::_report Filesystem false "The system drive is ${filesystem:-unknown}, TumbleGecko needs btrfs"
	fi
}

# PCI classes 0300, 0302 and 0380 are VGA, 3D and display controllers
preconditions::_graphics() {
	local devices count
	devices="$(lspci -nn 2>/dev/null | grep -E ' \[(0300|0302|0380)\]: ')"
	count="$(grep -c . <<< "${devices}")"
	if (( count == 1 )); then
		preconditions::_report Graphics true \
			"$(sed 's/.*: //; s/ \[[0-9a-f]\{4\}:[0-9a-f]\{4\}\].*//' <<< "${devices}")"
	else
		preconditions::_report Graphics false "Found ${count} graphics devices, TumbleGecko supports exactly one"
	fi
}

# Print every precondition as an event, returning failure when any of them failed
preconditions::check_all() {
	local failed=0 check
	for check in _distribution _desktop _session _filesystem _graphics; do
		"preconditions::${check}" || failed=1
	done
	return "${failed}"
}

# Make SDDM start Plasma Wayland at the next login, the documented way to leave an X11 session for good
# SDDM records the last session in this file, see sddm-state.conf(5)
preconditions::fix_session() {
	local session=plasmawayland.desktop state_file=/var/lib/sddm/state.conf
	[[ -f "/usr/share/wayland-sessions/${session}" ]] || {
		core::error "Plasma Wayland is not installed"
		return 1
	}
	core::as_root kwriteconfig6 --file "${state_file}" --group Last --key Session "${session}" || return 1
	core::as_root chown sddm:sddm "${state_file}" && core::as_root chmod 600 "${state_file}" || return 1
	[[ "$(core::as_root kreadconfig6 --file "${state_file}" --group Last --key Session)" == "${session}" ]]
}
