#!/usr/bin/env bash
# name:     .NET SDK
# summary:  Installs and updates the newest long term support .NET SDK in ~/.dotnet, for building C# and F# apps.
# default:  on
#
# Microsoft's dotnet-install.sh is the documented way to get the current SDK
# Source https://learn.microsoft.com/dotnet/core/install/linux-scripted-manual
#
# Its --dry-run names the newest SDK of the LTS channel, which is how the check knows an update exists
# This is native Linux .NET, while the dotnet48 in the Proton-GE task is Windows .NET inside Wine
#
# DOTNET_ROOT is Microsoft's documented setting for apps and IDEs to find the runtime, and telemetry is turned off

DOTNET="${HOME}/.dotnet"
DOTNET_CHANNEL=LTS

dotnet_installer() {
	local installer
	installer="$(mktemp)" || return 1
	curl -fsSL https://dot.net/v1/dotnet-install.sh -o "${installer}" && printf '%s\n' "${installer}"
}

newest_sdk() {
	local installer version
	installer="$(dotnet_installer)" || return 1
	version="$(bash "${installer}" --channel "${DOTNET_CHANNEL}" --install-dir "${DOTNET}" --dry-run 2>&1 \
		| sed -n 's/.*--version "\([^"]*\)".*/\1/p' | head -1)"
	rm -f "${installer}"
	[[ -n "${version}" ]] && printf '%s\n' "${version}"
}

newest_sdk_installed() {
	local newest
	newest="$(newest_sdk)" || return "${CORE_EXIT_UNKNOWN}"
	"${DOTNET}/dotnet" --list-sdks 2>/dev/null | grep -q "^${newest} "
}

install_newest_sdk() {
	local installer status=0
	installer="$(dotnet_installer)" || return 1
	bash "${installer}" --channel "${DOTNET_CHANNEL}" --install-dir "${DOTNET}" || status=1
	rm -f "${installer}"
	return "${status}"
}

task() {
	want::step "Install the newest .NET ${DOTNET_CHANNEL} SDK" network newest_sdk_installed install_newest_sdk
	want::symlink "${HOME}/.local/bin/dotnet" "${DOTNET}/dotnet"
	want::session_variable DOTNET_ROOT "${DOTNET}" "${HOME}/.config/environment.d/30-dotnet.conf"
	want::session_variable DOTNET_CLI_TELEMETRY_OPTOUT 1 "${HOME}/.config/environment.d/30-dotnet.conf"
}
