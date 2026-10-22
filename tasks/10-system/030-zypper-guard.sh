#!/usr/bin/env bash
# name:     Safe updates only
# summary:  Removes Discover and PackageKit and stops "zypper update", so the system is only ever updated the way Tumbleweed needs.
# default:  on
#
# On Tumbleweed "zypper dup ... is the only recommended way to update the system", and Discover cannot resolve conflicts
# Source https://en.opensuse.org/System_Updates
#
# Discover and the PackageKit apps are removed and locked, a dry run showed that touches only these ten packages
# The PackageKit libraries stay, about 20 Plasma packages need libpackagekitqt6 and it does nothing without the daemon
#
# /usr/local/bin/zypper refuses update, up and patch, and sudoers puts /usr/local/bin first so sudo zypper meets it too
# The sudoers entry must pass visudo before it is installed, so a mistake cannot lock anyone out of sudo
#
# Removing both files and running zypper removelock on the packages undoes it

DISCOVER_AND_PACKAGEKIT=(discover6 discover6-notifier discover6-backend-flatpak discover6-backend-fwupd
	discover6-backend-packagekit PackageKit PackageKit-backend-zypp PackageKit-branding-openSUSE
	PackageKit-gstreamer-plugin PackageKit-gtk3-module)

guard_script() {
	cat <<'SCRIPT'
#!/usr/bin/env bash
# Refuse zypper update, up and patch on Tumbleweed and run the real zypper for everything else
#
# Calling /usr/bin/zypper directly skips this guard

readonly EXIT_REFUSED=1
readonly REAL_ZYPPER=/usr/bin/zypper

# Print zypper's command, the first word that is not an option, wherever global options sit
zypper_command() {
	local word
	for word in "$@"; do
		[[ "${word}" == -* ]] && continue
		printf '%s\n' "${word}"
		return
	done
}

case "$(zypper_command "$@")" in
	update | up | patch)
		cat >&2 <<'WARNING'

Tumbleweed is a rolling release, and zypper update, up and patch can leave it half updated.
They skip the vendor changes, new packages and removals a rolling update needs.

Update with this instead.

    sudo zypper dup

https://en.opensuse.org/System_Updates says "zypper dup ... is the only recommended way to update the system".
This command was not run, call /usr/bin/zypper directly to run it anyway.

WARNING
		exit "${EXIT_REFUSED}"
		;;
esac

exec "${REAL_ZYPPER}" "$@"
SCRIPT
}

sudo_path() {
	cat <<'SUDOERS'
# TumbleGecko puts /usr/local/bin first, so sudo zypper meets the update guard too
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
SUDOERS
}

task() {
	want::no_packages "${DISCOVER_AND_PACKAGEKIT[@]}"
	want::package_locks "${DISCOVER_AND_PACKAGEKIT[@]}"
	want::file /usr/local/bin/zypper guard_script --root --mode 0755
	want::file /etc/sudoers.d/00-zypper-guard sudo_path --root --mode 0440 --validate "visudo -cf"
}
