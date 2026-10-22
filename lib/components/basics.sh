# lib/components/basics.sh, conditions and custom steps
#
# A custom step is for logic only one task has, so it still gets the same describe, check and apply contract

# Only run the task when a PCI device from this vendor is present
when::pci_vendor() {
	local vendor="$1" text="$2"
	task::condition "${text}" core::has_pci_vendor "${vendor}"
}

# Only run the task when a USB device from this vendor is attached
when::usb_vendor() {
	local vendor="$1" text="$2"
	task::condition "${text}" core::has_usb_vendor "${vendor}"
}

# Only run the task when a command is available
when::command() {
	local command_name="$1" text="$2"
	task::condition "${text}" command -v "${command_name}"
}

# A step with its own check and apply functions, written in the task
# needs lists what it uses, from sudo and network
want::step() {
	local text="$1" needs="$2" check_function="$3" apply_function="$4"
	shift 4
	task::requirement "${text}" "${needs}" "${check_function}" "${apply_function}" "$@"
}

# Only run the task when a check function written in the task passes
when::check() {
	local text="$1" check_function="$2"
	shift 2
	task::condition "${text}" "${check_function}" "$@"
}
