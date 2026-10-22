#!/usr/bin/env bash
# name:     Flatpak
# summary:  Installs Flatpak with Flathub for this user and Flatseal for app permissions.
# default:  on
#
# Flathub links and .flatpakref files open in Gecko Center, installed by its own task
# Everything goes in with --user, which needs no password

task() {
	want::packages --no-recommends flatpak flatpak-remote-flathub
	want::flatpak_remote flathub https://flathub.org/repo/flathub.flatpakrepo
	want::flatpak com.github.tchx84.Flatseal
}
