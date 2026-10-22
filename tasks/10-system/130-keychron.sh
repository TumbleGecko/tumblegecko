#!/usr/bin/env bash
# name:     Keychron
# summary:  Lets launcher.keychron.com configure and update Keychron devices, and stops Hall Effect keyboards showing up in games as a controller.
# default:  off
#
# The Launcher talks WebHID to each 3434 hidraw node, which is root only by default, so it connects and does nothing
# For firmware it reboots the board into the STM32 ROM bootloader, 0483:df11, and writes it over WebUSB
#
# Both lines tag the device uaccess, so logind gives the logged in user an ACL
# 73-seat-late.rules only applies uaccess to devices already tagged, so the file must sort before it
#
# Seen 2026-07-03, at 99- the node stayed root only and at 60- it worked at once
# The trigger only reruns the rules and does not reset the device, so it is safe in the middle of a firmware update
#
# The board has an analog gamepad on its keyboard interface, a pad with 6 axes and 16 buttons that never moves
# That brings controller prompts with nothing plugged in, and a real pad on player 2
#
# 60-input-id.rules sets ID_INPUT_JOYSTICK and 70-uaccess.rules hands out the ACL, so this rule must sort between them
# Below 60 there is nothing to clear and above 70 is too late, and both fail silently, checked 2026-07-29
#
# The distro's 51-these-are-not-joysticks-rm.rules has the same problem and is generated, so it is not edited
# KERNELS matches the HID parent BUS:VENDOR:PRODUCT, which covers USB, the receiver and Bluetooth in one line
#
# Only nodes carrying ID_INPUT_JOYSTICK match, so the keyboard, the mouse and real controllers are never touched
# The js node is deleted as well, because 50-udev-default.rules makes js nodes world readable without any ACL
#
# An existing device keeps logind's ACL and a sticky uaccess tag in the udev database until replugged
# So both are cleared before the trigger, and this task should go if a Keychron device is ever wanted as a gamepad

KEYCHRON=3434

keychron_rule() {
	cat <<'RULE'
# TumbleGecko: Keychron raw HID for launcher.keychron.com, and the STM32 bootloader for firmware updates
# Must sort before 73-seat-late.rules, or uaccess never applies
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", TAG+="uaccess"
RULE
}

keychron_nodes() {
	local device
	for device in /sys/class/hidraw/hidraw*; do
		grep -qi "^HID_ID=[0-9A-F]*:0000${KEYCHRON}:" "${device}/device/uevent" 2>/dev/null \
			&& printf '/dev/%s\n' "${device##*/}"
	done
}

nodes_usable() {
	local node
	while IFS= read -r node; do
		[[ -r "${node}" && -w "${node}" ]] || return 1
	done < <(keychron_nodes)
}

grant_access_now() {
	core::as_root udevadm trigger --action=add --subsystem-match=hidraw && core::as_root udevadm settle
}

no_gamepad_rule() {
	cat <<'RULE'
# TumbleGecko: a Keychron Hall Effect board's analog collection is not a joystick
# Must sort between 60-input-id.rules and 70-uaccess.rules
SUBSYSTEM=="input", KERNELS=="*:3434:*", ENV{ID_INPUT_JOYSTICK}=="?*", ENV{ID_INPUT_JOYSTICK}=""
SUBSYSTEM=="input", KERNELS=="*:3434:*", KERNEL=="js[0-9]*", RUN+="/bin/rm %E{DEVNAME}"
RULE
}

# Print the sysfs entry of every input node that belongs to a Keychron HID device
keychron_inputs() {
	local device
	for device in /sys/class/input/event* /sys/class/input/js*; do
		[[ -e "${device}" && "$(readlink -f "${device}")" == *:3434:* ]] && printf '%s\n' "${device}"
	done
}

# The by-id joystick link is made before the rule runs, so it still marks which node was the pad
phantom_pad_gone() {
	local device node
	while IFS= read -r device; do
		node="/dev/input/${device##*/}"
		[[ -e "${node}" ]] || continue
		[[ "${node}" == */js* ]] && return 1
		udevadm info -q property -n "${node}" | grep -q '^ID_INPUT_JOYSTICK=' && return 1
		readlink -f /dev/input/by-id/*-event-joystick 2>/dev/null | grep -qx "${node}" \
			&& [[ "$(ls -ld "${node}" | cut -c11)" == + ]] && return 1
	done < <(keychron_inputs)
	return 0
}

remove_phantom_pad() {
	local device node
	while IFS= read -r device; do
		core::as_root rm -f "/run/udev/data/c$(cat "${device}/dev")"
		core::as_root udevadm trigger --action=add "${device}"
	done < <(keychron_inputs)
	core::as_root udevadm settle
	while IFS= read -r device; do
		node="/dev/input/${device##*/}"
		[[ -e "${node}" ]] && core::as_root setfacl -b "${node}"
	done < <(keychron_inputs)
	return 0
}

task() {
	when::hid_vendor "${KEYCHRON}" "Only when a Keychron device is connected"
	want::udev_rule 60-keychron.rules keychron_rule
	want::step "Let you use the connected Keychron devices" sudo nodes_usable grant_access_now
	want::packages acl
	want::udev_rule 69-keychron-he-not-a-joystick.rules no_gamepad_rule
	want::step "Remove the phantom gamepad of connected Keychron keyboards" sudo phantom_pad_gone remove_phantom_pad
}
