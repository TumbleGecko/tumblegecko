# lib/components/flatpak.sh, Flatpak remotes and apps for this user
#
# Everything new is installed with --user, which needs no password

want::flatpak_remote() {
	local name="$1" address="$2"
	task::requirement "Add the ${name} Flatpak remote for this user" network \
		flatpak::_remote_present flatpak::_add_remote "${name}" "${address}"
}

flatpak::_remote_present() {
	flatpak remotes --user --columns=name 2>/dev/null | grep -qx -- "$1"
}

flatpak::_add_remote() {
	flatpak remote-add --user --if-not-exists "$1" "$2"
}

want::flatpak() {
	local app_id="$1" remote="${2:-flathub}"
	task::requirement "Install ${app_id} from ${remote}" network \
		flatpak::_installed flatpak::_install "${app_id}" "${remote}"
}

# An app installed for the whole system counts too, so it is never installed a second time
flatpak::_installed() {
	flatpak info "$1" >/dev/null 2>&1
}

flatpak::_install() {
	flatpak install --user --noninteractive --assumeyes "$2" "$1"
}
