#!/usr/bin/env bash
# Download TumbleGecko and open its installer, made to be piped from curl into bash
#
# Running it again replaces the copy with the newest one and keeps its logs

set -euo pipefail

readonly ARCHIVE_URL="https://github.com/TumbleGecko/tumblegecko/archive/refs/heads/main.tar.gz"
# Its own folder, beside the sources TumbleGecko keeps in ~/.local/share/tumblegecko
readonly DESTINATION="${XDG_DATA_HOME:-${HOME}/.local/share}/tumblegecko/installer"
# /tmp is memory on Tumbleweed, setup.sh keeps its temporary files here too
readonly DOWNLOADS="${XDG_CACHE_HOME:-${HOME}/.cache}/tumblegecko/tmp"


# Everything sits in one function, so a download cut short runs nothing
main() {
	local download
	# It sets up the desktop of whoever runs it, and as root that would be root's instead of yours
	if (( EUID == 0 )); then
		printf 'Run TumbleGecko as yourself, without sudo. It asks for your password when it needs it.\n' >&2
		return 1
	fi

	mkdir -p "${DOWNLOADS}"
	download="$(mktemp -d -p "${DOWNLOADS}")"
	trap "rm -rf '${download}'" EXIT

	printf 'Downloading TumbleGecko...\n'
	curl -fsSL "${ARCHIVE_URL}" | tar -xz -C "${download}" --strip-components=1

	# A task removed upstream must not stay behind and run, so the old copy goes except its logs
	mkdir -p "${DESTINATION}"
	find "${DESTINATION}" -mindepth 1 -maxdepth 1 ! -name logs -exec rm -rf {} +
	cp -a "${download}/." "${DESTINATION}/"

	# curl owns standard input, so setup.sh asks for a password through the terminal itself
	"${DESTINATION}/setup.sh" < /dev/tty
}

main "$@"
