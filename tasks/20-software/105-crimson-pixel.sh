#!/usr/bin/env bash
# name:     Crimson Pixel
# summary:  Installs Crimson Pixel, and middle-clicking a picture in Dolphin opens it there while a normal click opens qView.
# default:  on
# group:    Image software
#
# Crimson Pixel is our own project at https://github.com/Crimson-Org/crimson-pixel, followed at its newest release
# It is an editor, and qView stays the viewer that picture types open in by default
#
# Crimson Pixel sits behind qView only for the types both of them open
# Photoshop files are not among those, so Crimson Pixel is their default

PHOTOSHOP_TYPES=(image/vnd.adobe.photoshop)

task() {
	want::packages libadwaita-1-0 libpanel-1-1 libz1
	want::github_app Crimson-Org/crimson-pixel '-linux-{arch}\.tar\.gz$' crimson-pixel
	want::mime_default io.github.CrimsonOrg.CrimsonPixel.desktop "${PHOTOSHOP_TYPES[@]}"
	want::mime_secondary 'com.interversehq.qView.desktop;io.github.CrimsonOrg.CrimsonPixel.desktop' \
		'@com.interversehq.qView.desktop+io.github.CrimsonOrg.CrimsonPixel.desktop'
}
