#!/usr/bin/env bash
# name:     VLC
# summary:  Installs VLC and opens videos in it, while middle-clicking a video in Dolphin opens it in Avidemux.
# default:  on
# group:    Video software
#
# A type with no default goes to the app mimeinfo.cache lists first, and ~/.local/share outranks /usr/share
# So the generated avidemux.desktop took video over from VLC the first time that cache was rebuilt, 2026-08-02
#
# VLC gets every video type it declares, read from its installed .desktop
# Avidemux sits behind it only for the types both declare

task() {
	want::packages vlc
	want::mime_default vlc.desktop '@vlc.desktop:^video/'
	want::mime_secondary 'vlc.desktop;avidemux.desktop' '@vlc.desktop+avidemux.desktop:^video/'
}
