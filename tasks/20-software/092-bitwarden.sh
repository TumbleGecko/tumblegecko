#!/usr/bin/env bash
# name:     Bitwarden
# summary:  Installs the Bitwarden desktop app, beside the Bitwarden add-on Firefox gets.
# default:  on
# group:    Internet
#
# It comes from repo-oss

task() {
	want::packages --no-recommends bitwarden
}
