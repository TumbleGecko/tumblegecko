#!/usr/bin/env bash
# name:     Filelight
# summary:  Shows what is filling your disk as a clickable ring chart.
# default:  on
# group:    Files and text

task() {
	want::packages --no-recommends filelight
}
