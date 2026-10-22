#!/usr/bin/env bash
# name:     Git and GitHub CLI
# summary:  Installs git and the GitHub CLI, gh.
# default:  on
#
# Both come from repo-oss

task() {
	want::packages --no-recommends git gh
}
