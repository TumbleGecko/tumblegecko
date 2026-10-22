#!/usr/bin/env bash
# name:     ArtCraft Launcher
# summary:  Installs the ArtCraft Launcher, which installs and updates every Craft app.
# default:  on
# group:    ArtCraft
#
# The launcher is in no openSUSE repository, and upstream publishes an rpm with every release
# It installs and updates every Craft app with that same rpm through zypper, and finds ones installed by hand
#
# Source https://github.com/storytold/craft-launcher#where-apps-are-installed

task() {
	want::github_rpm storytold/craft-launcher artcraft-launcher '-linux-{arch}\.rpm$'
}
