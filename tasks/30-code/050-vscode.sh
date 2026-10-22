#!/usr/bin/env bash
# name:     Visual Studio Code
# summary:  Installs VS Code from Microsoft's own repository, so it updates with the rest of the system.
# default:  on
#
# Microsoft's repository is an accepted third party repository, approved 2026-08-05
# The address and key are the ones Microsoft documents for openSUSE
#
# Source https://code.visualstudio.com/docs/setup/linux#_opensuse-and-slebased-distributions

task() {
	want::repository vscode https://packages.microsoft.com/yumrepos/vscode --priority 99 \
		--key https://packages.microsoft.com/keys/microsoft.asc
	want::packages code
}
