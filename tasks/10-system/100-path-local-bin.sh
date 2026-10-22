#!/usr/bin/env bash
# name:     Your own programs folder on the PATH
# summary:  Programs installed into ~/.local/bin start from any terminal, launcher or service.
# default:  on
#
# Three places, because each kind of start reads a different one
# Login shells read /etc/profile.d and openSUSE's /etc/bash.bashrc does not, so new terminal tabs need ~/.bashrc too
#
# The desktop session and every user service get their environment from systemd --user, which reads environment.d
# %h is the home folder there, see environment.d(5)

profile_script() {
	cat <<'SCRIPT'
# TumbleGecko: ~/.local/bin on the PATH for login shells
if [ -d "$HOME/.local/bin" ]; then
	case ":$PATH:" in
		*":$HOME/.local/bin:"*) ;;
		*) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
	esac
fi
SCRIPT
}

session_path() {
	printf '%s\n' '# TumbleGecko: ~/.local/bin on the PATH for the desktop session' 'PATH=%h/.local/bin:${PATH}'
}

bash_path() {
	cat <<'SCRIPT'
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	PATH="$HOME/.local/bin:$PATH"
	export PATH
fi
SCRIPT
}

task() {
	want::file /etc/profile.d/00-local-bin.sh profile_script --root
	want::file "${HOME}/.config/environment.d/10-local-bin.conf" session_path
	want::block "${HOME}/.bashrc" local-bin-path bash_path
	restart::if_changed "Programs in ~/.local/bin are found everywhere after you log in again"
}
