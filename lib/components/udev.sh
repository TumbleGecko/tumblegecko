# lib/components/udev.sh, udev rules

# Install a rule file in /etc/udev/rules.d and make udev load it
# The number in a rule's name decides when it runs, which matters for uaccess and input rules
want::udev_rule() {
	local name="$1" content_function="$2"
	want::file "/etc/udev/rules.d/${name}" "${content_function}" --root --then udev::reload
}

udev::reload() {
	core::as_root udevadm control --reload-rules
}

# Print the HID vendor of every hidraw node, which covers USB, receivers and Bluetooth alike
udev::hidraw_vendors() {
	sed -n 's/^HID_ID=[0-9A-F]*:0000\([0-9A-F]*\):.*/\1/p' /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null
}

# Only run the task when a HID device from this vendor is connected, by USB, a receiver or Bluetooth
when::hid_vendor() {
	local vendor="$1" text="$2"
	task::condition "${text}" udev::_hid_vendor_connected "${vendor}"
}

udev::_hid_vendor_connected() {
	core::has_usb_vendor "$1" || udev::hidraw_vendors | grep -qix "$1"
}
