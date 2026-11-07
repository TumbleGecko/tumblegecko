#!/usr/bin/env bash
# name:     Crimson Changes
# summary:  Installs Crimson Changes, a Git diff and history viewer, with Open in Crimson Changes in Dolphin's right-click menu for folders.
# default:  on
#
# Crimson Changes is our own project at https://github.com/Crimson-Org/crimson-changes, followed at its newest release
# Its release brings the Dolphin service menu, which want::github_app writes out like a launcher
# It never becomes the default app for folders, so folders keep opening in Dolphin

task() {
	want::packages git libadwaita-1-0 libgtksourceview-5-0
	want::github_app Crimson-Org/crimson-changes '-linux-{arch}\.tar\.gz$' crimson-changes
}
