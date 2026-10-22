#!/usr/bin/env bash
# Start TumbleGecko, the installer window or one engine command
#
# With no arguments it installs what the window needs and opens it
# The other commands print engine events, as text or with --events as JSON lines

set -uo pipefail

readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_USAGE=2

TUMBLEGECKO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TUMBLEGECKO_LIB="${TUMBLEGECKO_ROOT}/lib"
TUMBLEGECKO_TASKS="${TUMBLEGECKO_ROOT}/tasks"
TUMBLEGECKO_LOGS="${TUMBLEGECKO_ROOT}/logs"
export TUMBLEGECKO_ROOT TUMBLEGECKO_LIB TUMBLEGECKO_TASKS TUMBLEGECKO_LOGS

# /tmp is memory on Tumbleweed and some downloads unpack to over a gigabyte
# So temporary files go to disk unless the caller chose a place
if [[ -z "${TMPDIR:-}" ]]; then
	TMPDIR="${XDG_CACHE_HOME:-${HOME}/.cache}/tumblegecko/tmp"
	mkdir -p "${TMPDIR}"
	export TMPDIR
fi

# What the engine and the window need, named by capability so no Python version is written here
readonly BOOTSTRAP_PACKAGES=(jq python3-pyside6 ibm-plex-sans-fonts ibm-plex-mono-fonts)

# shellcheck source=lib/core.sh
. "${TUMBLEGECKO_LIB}/core.sh"
# shellcheck source=lib/engine.sh
. "${TUMBLEGECKO_LIB}/engine.sh"
# shellcheck source=lib/preconditions.sh
. "${TUMBLEGECKO_LIB}/preconditions.sh"


usage() {
	cat <<'EOF'
Usage: ./setup.sh [command] [--events]

  (no command)           Open the TumbleGecko installer window
  --list                 List every task with its id
  --catalog              Print every task and what it does as JSON
  --preconditions        Check that this machine is one TumbleGecko supports
  --check [task ids]     Show which tasks still have work to do, without changing anything
  --run <task ids>       Set up the given tasks, --run --all for every task that is on by default
  --fix-session          Make the next login start Plasma Wayland

  --events               Print engine events as JSON lines instead of text
EOF
}

# Install the window's own packages from the openSUSE repositories when any are missing
# zypper resolves each capability to the right package
bootstrap() {
	local package missing=()
	for package in "${BOOTSTRAP_PACKAGES[@]}"; do
		rpm -q --quiet --whatprovides "${package}" || missing+=("${package}")
	done
	(( ${#missing[@]} == 0 )) && return 0

	printf 'TumbleGecko needs %s first.\n' "${missing[*]}"
	if [[ -t 0 ]]; then
		sudo zypper --non-interactive install "${missing[@]}"
	else
		pkexec zypper --non-interactive install "${missing[@]}"
	fi
}

# The desktop finds the window's name and icon through this entry, and the app menu offers it again
# It is written on every start, so it follows the folder if it moves
write_launcher() {
	local directory="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
	mkdir -p "${directory}" && cat > "${directory}/tumblegecko.desktop" <<ENTRY
[Desktop Entry]
Type=Application
Name=TumbleGecko
Comment=Set up and tune openSUSE Tumbleweed
Exec=${TUMBLEGECKO_ROOT}/setup.sh
Icon=${TUMBLEGECKO_ROOT}/gui/gecko-ui/assets/gecko.png
Terminal=false
Categories=System;Settings;
ENTRY
}

# Ask for the password once before a terminal run and keep sudo's ticket fresh until the run ends
# The sleep paces the refresh, sudo forgets the password after a few idle minutes
keep_sudo_alive() {
	# sudo -v asks for a password even under NOPASSWD, so a sudo that already runs without one is left alone
	sudo -n true 2>/dev/null && return 0
	sudo -v || return 1
	while kill -0 "$$" 2>/dev/null; do
		sleep 60
		sudo -n -v 2>/dev/null
	done &
}

# Print the ids of the tasks that are on by default
default_task_ids() {
	engine::catalog | jq -r '.[] | select(.default) | .id'
}

# The given tasks need root when a step that is not done yet does
tasks_need_sudo() {
	engine::check "$@" | jq -se '[.[].requirements[] | select(.state != "satisfied" and (.needs | test("sudo")))]
		| length > 0' >/dev/null
}

run_command() {
	local command="$1" events="$2"
	shift 2
	local present=engine::present ids
	(( events )) && present=cat

	case "${command}" in
		list)
			engine::catalog | jq -r '.[] | "\(.id)\t\(.name)"' | column -t -s $'\t'
			;;
		catalog)
			engine::catalog
			;;
		preconditions)
			preconditions::check_all | "${present}"
			return "${PIPESTATUS[0]}"
			;;
		check)
			engine::check "$@" | "${present}"
			;;
		run)
			if [[ "${1:-}" == --all ]]; then
				mapfile -t ids < <(default_task_ids)
				set -- "${ids[@]}"
			fi
			(( $# )) || { usage >&2; return "${EXIT_USAGE}"; }
			if ! preconditions::check_all > /dev/null; then
				preconditions::check_all | "${present}"
				return "${EXIT_FAILURE}"
			fi
			if [[ -z "${SUDO_ASKPASS:-}" ]] && tasks_need_sudo "$@"; then
				keep_sudo_alive || return "${EXIT_FAILURE}"
			fi
			engine::run "$@" | "${present}"
			return "${PIPESTATUS[0]}"
			;;
		fix-session)
			preconditions::fix_session
			;;
		window)
			bootstrap || return "${EXIT_FAILURE}"
			write_launcher
			mkdir -p "${TUMBLEGECKO_LOGS}"
			python3 "${TUMBLEGECKO_ROOT}/gui/tumblegecko.py" 2> >(tee -a "${TUMBLEGECKO_LOGS}/window.log" >&2)
			;;
	esac
}

main() {
	local command=window events=0 arguments=()
	# It sets up the desktop of whoever runs it, and as root that would be root's instead of yours
	if (( EUID == 0 )); then
		printf 'Run TumbleGecko as yourself, without sudo. It asks for your password when it needs it.\n' >&2
		return "${EXIT_FAILURE}"
	fi

	while (( $# )); do
		case "$1" in
			--events) events=1 ;;
			--list | --catalog | --preconditions | --check | --run | --fix-session) command="${1#--}" ;;
			-h | --help) usage; return "${EXIT_SUCCESS}" ;;
			--all) arguments+=("$1") ;;
			-*) usage >&2; return "${EXIT_USAGE}" ;;
			*) arguments+=("$1") ;;
		esac
		shift
	done
	if [[ "${command}" != window ]] && ! command -v jq >/dev/null; then
		bootstrap || return "${EXIT_FAILURE}"
	fi
	run_command "${command}" "${events}" "${arguments[@]}"
}

# One line, so bash has read all of it before running and an edited file cannot break a long session
main "$@"; exit $?
