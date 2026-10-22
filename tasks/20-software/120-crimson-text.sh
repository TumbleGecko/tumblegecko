#!/usr/bin/env bash
# name:     Crimson Text
# summary:  Installs Crimson Text, and opens text, Markdown and log files in it, with middle-click in Dolphin opening its editor.
# default:  on
# group:    Files and text
#
# Crimson Text is our own project at https://github.com/Crimson-Org/crimson-text, followed at its newest release
# It reads Markdown as a page and opens other text in a coloured editor
#
# Config, data and code files belong to Crimson Code, so only plain text, Markdown, tables and logs are listed here
# Middle-click opens the first app after the default, which is Crimson Text with --edit
# The Crimson Code task puts itself next, for Shift and middle-click

task() {
	want::packages libadwaita-1-0 libgtksourceview-5-0 libcurl4 libglycin-2-0 glycin-loaders
	want::github_app Crimson-Org/crimson-text '-linux-{arch}\.tar\.gz$' crimson-text
	want::mime_default io.github.CrimsonOrg.CrimsonText.desktop "${MIME_TEXT_TYPES[@]}"
	want::mime_secondary 'io.github.CrimsonOrg.CrimsonText.desktop;io.github.CrimsonOrg.CrimsonText.Edit.desktop' "${MIME_TEXT_TYPES[@]}"
}
