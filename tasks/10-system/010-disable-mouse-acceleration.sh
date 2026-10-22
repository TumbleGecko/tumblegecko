#!/usr/bin/env bash
# name:     No mouse acceleration
# summary:  Pointer speed follows your hand exactly, on every mouse, without logging out.
# default:  on
#
# KWin keeps per device settings in kcminputrc as [Libinput][<vendor>][<product>][<name>], with decimal numbers
# Source is the m_config group chain in kwin src/backends/libinput/connection.cpp
#
# PointerAccelerationProfile 1 is libinput's flat profile and 2 the default adaptive one
# Source https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html
#
# KWin reapplies it on the KGlobalSettings notifyChange signal with type 3 and argument 0, the mouse settings
# Touchpads keep their acceleration

FLAT_PROFILE=1

# Print vendor, product and name for every attached mouse, tab separated, from udev's input properties
pointer_devices() {
	local device properties vendor product name
	for device in /sys/class/input/event*; do
		properties="$(udevadm info --query=property "${device}" 2>/dev/null)" || continue
		[[ "${properties}" == *ID_INPUT_MOUSE=1* && "${properties}" != *ID_INPUT_TOUCHPAD=1* ]] || continue
		vendor="$(cat "${device}/device/id/vendor" 2>/dev/null)"
		product="$(cat "${device}/device/id/product" 2>/dev/null)"
		name="$(cat "${device}/device/name" 2>/dev/null)"
		[[ -n "${vendor}" && -n "${product}" && -n "${name}" ]] || continue
		printf '%d\t%d\t%s\n' "$((16#${vendor}))" "$((16#${product}))" "${name}"
	done | sort -u
}

all_flat() {
	local vendor product name
	while IFS=$'\t' read -r vendor product name; do
		[[ "$(kreadconfig6 --file kcminputrc --group Libinput --group "${vendor}" --group "${product}" \
			--group "${name}" --key PointerAccelerationProfile)" == "${FLAT_PROFILE}" ]] || return 1
	done < <(pointer_devices)
}

make_flat() {
	local vendor product name
	while IFS=$'\t' read -r vendor product name; do
		kwriteconfig6 --file kcminputrc --group Libinput --group "${vendor}" --group "${product}" \
			--group "${name}" --key PointerAccelerationProfile "${FLAT_PROFILE}" || return 1
	done < <(pointer_devices)
}

reload_mouse_settings() {
	dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:3 int32:0
}

task() {
	want::step "Turn off acceleration on every attached mouse" "" all_flat make_flat
	on_change reload_mouse_settings
}
