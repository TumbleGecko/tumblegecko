#!/usr/bin/env bash
# name:     qView
# summary:  Installs qView, a fast minimal picture viewer, and opens pictures in it with dark title bars and folder looping.
# default:  on
# group:    Image software
#
# qView becomes the default for every type its own .desktop declares, which out of the box mostly go to Gwenview
# Photoshop files are left out, since Crimson Pixel opens those and qView cannot
# Its settings file is Qt's INI format, and only the options below are managed, so what qView adds itself stays

QVIEW_OPTIONS=(afterdelete=2 allowmimecontentdetection=false askdelete=true bgcolorenabled=false colorspaceconversion=1
	cropmode=0 cursorzoom=true filteringenabled=false fractionalzoom=false fullscreendetails=false language=system
	loopfoldersenabled=true menubarenabled=false preloadingmode=1 quitonlastwindow=false scalefactor=25
	scalingenabled=true scrollzoom=1 skiphidden=true slideshowreversed=0 slideshowtimer=5 sortdescending=0 sortmode=0
	titlebaralwaysdark=true titlebarmode=2 updatenotifications=false)

task() {
	want::packages qview
	want::mime_default com.interversehq.qView.desktop '@com.interversehq.qView.desktop:!photoshop|psd'
	want::ini_values "${HOME}/.config/qView/qView.conf" options "${QVIEW_OPTIONS[@]}"
}
