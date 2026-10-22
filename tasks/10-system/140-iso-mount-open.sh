#!/usr/bin/env bash
# name:     Open disc images with a double-click
# summary:  Double-clicking an ISO mounts it read-only and opens it in Dolphin, with an eject button in Places.
# default:  on
#
# Without this an .iso opens in Ark as an archive
# mount-iso sets up a read only loop device and mounts it through udisks2, which polkit allows the active session
#
# After mounting it marks the loop autoclear, so unmounting or ejecting also detaches it
# It has to come after the mount, because an idle loop with autoclear detaches at once
#
# Without autoclear a plain unmount leaves the loop holding a deleted image open
# A udisks loop device is HintSystem by default and Solid hides it, so the rule marks it removable for the eject button
#
# 99- is fine here, these are hints udisks reads and not a builtin that depends on rule order
# application/vnd.efi.iso is the type and the other two are its aliases

MOUNT_ISO="${HOME}/.local/bin/mount-iso"
DISC_IMAGE_TYPES=(application/vnd.efi.iso application/x-cd-image application/x-iso9660-image)

mount_iso_script() {
	cat <<'SCRIPT'
#!/usr/bin/env bash
# Mount a disc image read only through udisks2 and open it in the file manager
#
# polkit grants loop-setup and filesystem-mount to the active session, so no password is needed

readonly EXIT_FAILURE=1

# A double-click has no console, so a failure shows in a dialog as well
fail() {
	local message="$1"
	printf 'mount-iso: %s\n' "${message}" >&2
	command -v kdialog >/dev/null && kdialog --title "Mount disc image" --error "${message}" >/dev/null 2>&1
	exit "${EXIT_FAILURE}"
}

# Print where an image is mounted already, so a second double-click only opens it again
mounted_at() {
	local image="$1" backing_file backing device
	for backing_file in /sys/block/loop*/loop/backing_file; do
		[[ -r "${backing_file}" ]] || continue
		IFS= read -r backing < "${backing_file}" || continue
		[[ "${backing}" == "${image}" ]] || continue
		device="${backing_file#/sys/block/}"
		findmnt -n -o TARGET "/dev/${device%%/*}" 2>/dev/null | head -1 | grep . && return 0
	done
	return 1
}

image="${1:-}"
[[ -n "${image}" ]] || fail "No file given"
image="$(realpath -e -- "${image}" 2>/dev/null)" || fail "The file does not exist: ${1}"
[[ -f "${image}" ]] || fail "Not a regular file: ${image}"

if mount_point="$(mounted_at "${image}")"; then
	exec xdg-open "${mount_point}"
fi

output="$(udisksctl loop-setup -r -f "${image}" --no-user-interaction 2>&1)" \
	|| fail "Could not set up a loop device for ${image}: ${output}"
device="$(grep -oE '/dev/loop[0-9]+' <<< "${output}" | head -1)"
[[ -n "${device}" ]] || fail "udisks did not report a loop device: ${output}"

output="$(udisksctl mount -b "${device}" --no-user-interaction 2>&1)" \
	|| fail "Set up ${device} for ${image} but could not mount it: ${output}"

# Autoclear makes unmounting or ejecting also detach the loop, so nothing keeps the image open
# It must come after the mount, because an idle loop with autoclear detaches at once
if ! busctl call org.freedesktop.UDisks2 "/org/freedesktop/UDisks2/block_devices/${device##*/}" \
	org.freedesktop.UDisks2.Loop SetAutoclear "ba{sv}" true 0 >/dev/null 2>&1; then
	printf 'mount-iso: %s stays attached after unmounting, autoclear could not be set\n' "${device}" >&2
fi

mount_point="$(findmnt -n -o TARGET "${device}" 2>/dev/null | head -1)"
[[ -n "${mount_point}" ]] || fail "Mounted ${device} but could not find where"
exec xdg-open "${mount_point}"
SCRIPT
}

eject_rule() {
	cat <<'RULE'
# TumbleGecko shows mounted disc images as removable so Dolphin offers eject, and mount-iso does the mounting
SUBSYSTEM=="block", KERNEL=="loop*", ENV{ID_FS_USAGE}=="filesystem", ENV{UDISKS_SYSTEM}="0", ENV{UDISKS_AUTO}="0"
RULE
}

# Print every loop device whose image was deleted and that is not mounted, a leftover from before this task
stale_loops() {
	local backing_file line device
	for backing_file in /sys/block/loop*/loop/backing_file; do
		IFS= read -r line < "${backing_file}" 2>/dev/null || continue
		[[ "${line}" == *" (deleted)" ]] || continue
		device="${backing_file#/sys/block/}"
		device="/dev/${device%%/*}"
		findmnt -n "${device}" >/dev/null || printf '%s\n' "${device}"
	done
}

no_stale_loops() {
	[[ -z "$(stale_loops)" ]]
}

detach_stale_loops() {
	local device
	while IFS= read -r device; do
		udisksctl loop-delete -b "${device}" --no-user-interaction || core::as_root losetup -d "${device}" || return 1
	done < <(stale_loops)
}

refresh_loop_devices() {
	core::as_root udevadm trigger --action=change --subsystem-match=block --sysname-match='loop[0-9]*'
}

task() {
	want::packages --no-recommends udisks2 kdialog
	want::file "${MOUNT_ISO}" mount_iso_script --mode 0755
	want::handler mount-iso.desktop "Mount disc image" media-optical "${MOUNT_ISO} %f" "${DISC_IMAGE_TYPES[@]}"
	want::udev_rule 99-udisks-loop-eject.rules eject_rule
	want::step "Detach disc images left behind after their file was deleted" "" no_stale_loops detach_stale_loops
	on_change refresh_loop_devices
}
