#!/usr/bin/env bash
# name:     Audacity
# summary:  Installs Audacity, and middle-clicking a music file in Dolphin opens it there while a normal click still plays it.
# default:  on
# group:    Audio software
#
# Only formats Audacity can import, so no playlists, cue sheets, trackers or MIDI

EDITABLE_AUDIO=(audio/mpeg audio/x-mpeg audio/mp3 application/ogg application/x-ogg audio/ogg audio/x-vorbis+ogg
	audio/opus audio/x-opus+ogg audio/flac audio/x-flac audio/wav audio/x-wav audio/aiff audio/x-aiff audio/aac
	audio/mp4 audio/m4a)

task() {
	want::packages --no-recommends audacity
	want::mime_secondary 'deadbeef.desktop;audacity.desktop' "${EDITABLE_AUDIO[@]}"
}
