#!/usr/bin/env bash
# name:     Arctis Sound Manager
# summary:  Installs Arctis Sound Manager, which gives a SteelSeries Arctis headset its Game, Chat and Media outputs, the ChatMix dial, a mixer and an equalizer.
# default:  off
#
# Arctis Sound Manager is https://github.com/loteran/Arctis-Sound-Manager, followed at its newest release
# It is in no openSUSE repository, so the wheel from the release is installed with pipx
# Its asm-setup then writes the udev rules and the user services, the same way the project's own install script does
#
# Only when a SteelSeries headset is connected, since every other machine has nothing for it to manage

set_up() {
	systemctl --user is-enabled --quiet arctis-manager.service
}

run_setup() {
	"${HOME}/.local/bin/asm-setup"
}

task() {
	when::hid_vendor 1038 "Only when a SteelSeries headset is connected"
	want::packages python313-pipx libusb-1_0-0 libpulse0 libudev1 ladspa-swh-plugins
	want::github_pipx loteran/Arctis-Sound-Manager 'arctis_sound_manager-.*-py3-none-any\.whl$' asm-daemon
	want::step "Set up the udev rules and services" "sudo" set_up run_setup
}
