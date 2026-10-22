#!/usr/bin/env bash
# name:     Avidemux
# summary:  Installs the newest Avidemux from its own releases, for quick cuts and re-encodes.
# default:  on
# group:    Video software
#
# Avidemux is in no accepted repository, only Packman Multimedia
# Upstream publishes an AppImage with a checksum file beside it for every release
#
# Its .desktop claims some video types, and the VLC task keeps VLC their default

task() {
	want::appimage mean00/avidemux2 '^avidemux_[0-9.]+\.appImage$' avidemux
}
