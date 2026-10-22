#!/usr/bin/env bash
# name:     OBS Studio
# summary:  Installs OBS Studio for recording the screen and streaming.
# default:  on
# group:    Video software
#
# It comes from repo-oss

task() {
	want::packages --no-recommends obs-studio
}
