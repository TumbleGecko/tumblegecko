# lib/core.sh, shared basics for the engine, its components and every task
#
# Logging, event output, running things as root and small system queries live here

CORE_EXIT_SUCCESS=0
CORE_EXIT_FAILURE=1
# A check that cannot tell, distinct from the 2 that grep, cmp and others return for an error
CORE_EXIT_UNKNOWN=100

# Marks a line on a task's output as an engine event rather than log text
CORE_EVENT_MARKER=$'\x1e'


# ============================================================================
# Logging

core::log() {
	local level="$1"
	shift
	printf '%s: %s\n' "${level}" "$*" >&2
}

core::info() { core::log INFO "$@"; }
core::warn() { core::log WARN "$@"; }
core::error() { core::log ERROR "$@"; }


# ============================================================================
# Events

# Print one engine event as a JSON line
# Arguments are key=value strings, and a key ending in a colon takes a raw JSON value
core::event() {
	local event="$1"
	shift
	local arguments=(--arg event "${event}") filter='{event: $event' pair key value
	for pair in "$@"; do
		key="${pair%%=*}"
		value="${pair#*=}"
		if [[ "${key}" == *: ]]; then
			key="${key%:}"
			arguments+=(--argjson "${key}" "${value}")
		else
			arguments+=(--arg "${key}" "${value}")
		fi
		filter+=", ${key}: \$${key}"
	done
	jq -nc "${arguments[@]}" "${filter}}"
}

# Send an event from inside a running task, where stdout is the task's log stream
core::task_event() {
	printf '%s%s\n' "${CORE_EVENT_MARKER}" "$(core::event "$@")"
}


# ============================================================================
# Running as root

# Run a command as root, and the installer window supplies SUDO_ASKPASS so sudo can ask it for the password
# While the engine only describes or checks it never asks, so looking at the system cannot pop a prompt
core::as_root() {
	if [[ "${TASK_MODE:-apply}" != apply ]]; then
		sudo -n -- "$@"
	elif [[ -n "${SUDO_ASKPASS:-}" ]]; then
		sudo --askpass -- "$@"
	else
		sudo -- "$@"
	fi
}

# True when root is available right now without asking anyone, such as a cached sudo ticket
# Checks use this so that looking never pops a password prompt
core::root_without_asking() {
	sudo -n true 2>/dev/null
}

core::zypper() {
	core::as_root zypper --non-interactive --no-color "$@"
}

# Write standard input to a file owned by root with the given mode
core::write_root_file() {
	local path="$1" mode="$2" staged status=0
	staged="$(mktemp)" || return 1
	cat > "${staged}"
	core::as_root install -D -o root -g root -m "${mode}" "${staged}" "${path}" || status=1
	rm -f "${staged}"
	return "${status}"
}


# Wait until a condition holds, checking every half second, for at most the given seconds
# For changes another program writes in its own time, such as plasmashell saving a new panel
core::wait_until() {
	local seconds="$1" attempts
	shift
	for (( attempts = seconds * 2; attempts > 0; attempts-- )); do
		"$@" && return 0
		sleep 0.5
	done
	"$@"
}


# ============================================================================
# System queries

# True when an installed package has this name or provides it as a capability, such as python3-pyside6
core::package_installed() {
	rpm -q --quiet --whatprovides "$1"
}

# True when a PCI device from the given vendor id is present, such as 10de for NVIDIA
core::has_pci_vendor() {
	lspci -n -d "$1:" 2>/dev/null | grep -q .
}

# True when a USB device from the given vendor id is attached, such as 3434 for Keychron
core::has_usb_vendor() {
	grep -qix "$1" /sys/bus/usb/devices/*/idVendor 2>/dev/null
}

# Print every package name in the enabled repositories containing a word
# zypper's XML output is used because its table layout is not a stable interface
core::available_packages() {
	zypper --no-refresh --xmlout search --type package --match-substrings -- "$1" 2>/dev/null \
		| grep -o ' name="[^"]*"' | sed 's/ name="\(.*\)"/\1/' | sort -u
}

# Print the highest numbered package named prefix<N>suffix, such as nvidia-open-driver-G<N>-signed-kmp-meta
core::newest_numbered_package() {
	local prefix="$1" suffix="$2" name number highest=-1 best=""
	while IFS= read -r name; do
		[[ "${name}" =~ ^${prefix}([0-9]+)${suffix}$ ]] || continue
		number=$((10#${BASH_REMATCH[1]}))
		if (( number > highest )); then
			highest="${number}"
			best="${name}"
		fi
	done < <(core::available_packages "${prefix}")
	[[ -n "${best}" ]] || return 1
	printf '%s\n' "${best}"
}

# True when an installed version is older than the given one
# Older rather than different, so an app that updates itself is never downgraded
core::version_is_older() {
	local installed="$1" latest="$2"
	[[ "${installed}" != "${latest}" ]] || return 1
	[[ "$(printf '%s\n%s\n' "${installed}" "${latest}" | sort -V | head -1)" == "${installed}" ]]
}

# Print the version inside a tag or label such as v1.2.3, app-v1.2.3 or "App v1.2.3"
core::version_from_text() {
	local text="$1"
	text="${text#"${text%%[0-9]*}"}"
	printf '%s\n' "${text%%[!0-9A-Za-z.+-]*}"
}

# Print the path of a .desktop file by id, the user's own copy first, the way the desktop looks them up
core::desktop_file() {
	local desktop_id="$1" directory
	for directory in "${XDG_DATA_HOME:-${HOME}/.local/share}" ${XDG_DATA_DIRS//:/ } /usr/local/share /usr/share; do
		[[ -f "${directory}/applications/${desktop_id}" ]] && {
			printf '%s\n' "${directory}/applications/${desktop_id}"
			return 0
		}
	done
	return 1
}

# Print a .desktop file's own Name
core::desktop_name() {
	local file
	file="$(core::desktop_file "$1")" || { printf '%s\n' "${1%.desktop}"; return; }
	awk -F= '/^Name=/ { print $2; exit }' "${file}"
}
