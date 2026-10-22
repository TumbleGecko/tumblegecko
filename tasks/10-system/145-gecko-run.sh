#!/usr/bin/env bash
# name:     gecko-run
# summary:  Installs gecko-run, which starts any double-clicked Windows or DOS program the right way for what it is.
# default:  on
#
# gecko-run is our own project at https://github.com/TumbleGecko/gecko-run, followed at its newest main commit
# It reads each file's header, so a DOS program never ends up in Wine and a Windows installer never in an archiver
#
# Its own --install registers the file types, so the list lives in one place
# Linux programs and scripts keep KDE's own behaviour, which asks before running them
# It runs again whenever a newer commit arrives, so new file types reach this machine too

SOURCE="${HOME}/.local/share/tumblegecko/sources/gecko-run"
INSTALLED="${HOME}/.local/share/gecko-run"

installed_and_current() {
	[[ -x "${HOME}/.local/bin/gecko-run" ]] || return 1
	diff -rq --exclude=__pycache__ "${SOURCE}/src" "${INSTALLED}/src" >/dev/null 2>&1 || return 1
	[[ "$(xdg-mime query default application/x-dosexec)" == gecko-run.desktop ]]
}

install_gecko_run() {
	"${SOURCE}/gecko-run" --install
}

task() {
	want::git_branch https://github.com/TumbleGecko/gecko-run.git main "${SOURCE}"
	want::step "Install gecko-run and open program files with it" "" installed_and_current install_gecko_run
}
