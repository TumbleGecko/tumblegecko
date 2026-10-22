#!/usr/bin/env bash
# name:     Crimson Music
# summary:  Installs Crimson Music, a player for your YouTube Music playlists with a tray icon.
# default:  on
# group:    Audio software
#
# Crimson Music is our own project at https://github.com/Crimson-Org/crimson-music, followed at its newest release
# It streams from YouTube Music through GStreamer, so local music files stay with DeaDBeeF

task() {
	want::packages libadwaita-1-0 libwebkitgtk-6_0-4 libsoup-3_0-0 libsqlite3-0 libgstreamer-1_0-0 \
		gstreamer-plugins-base gstreamer-plugins-good
	want::github_app Crimson-Org/crimson-music '-linux-{arch}\.tar\.gz$' crimson-music
}
