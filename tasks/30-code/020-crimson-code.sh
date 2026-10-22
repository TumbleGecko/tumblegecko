#!/usr/bin/env bash
# name:     Crimson Code
# summary:  Installs Crimson Code, and opens source code, scripts, config and data files such as JSON, INI, TOML and YAML in it.
# default:  on
#
# Crimson Code is our own project at https://github.com/Crimson-Org/crimson-code, followed at its newest release
# Crimson Text keeps plain text, Markdown, tables and logs, with Crimson Code after its editor in Open With
# Shift and middle-click opens them in Crimson Code, or middle-click alone without Crimson Text
# KDE asks whether to run or open an executable shell script, and opening one uses Crimson Code
#
# .ini, .conf, .cfg, .env, .properties and .gitignore files are plain text to the desktop, like .txt files
# A file type of their own, made from their names, lets them open in Crimson Code while .txt files open in Crimson Text
#
# .ts shows up as text/vnd.trolltech.linguist, because Qt translations share TypeScript's extension

CONFIG_TYPE=application/x-crimson-config
CONFIG_PACKAGE="${XDG_DATA_HOME:-${HOME}/.local/share}/mime/packages/crimson-config.xml"

CODE_TYPES=(
	text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr text/x-python
	application/x-perl application/x-ruby application/x-php text/javascript text/vnd.trolltech.linguist
	application/x-shellscript text/x-makefile text/css text/rust text/x-go text/x-java text/x-lua
	application/json application/toml application/yaml application/xml text/xml "${CONFIG_TYPE}"
)

config_type_written() {
	[[ -f "${CONFIG_PACKAGE}" ]] && grep -q 'x-crimson-config' "${CONFIG_PACKAGE}"
}

write_config_type() {
	mkdir -p "${CONFIG_PACKAGE%/*}" && cat > "${CONFIG_PACKAGE}" <<'XML' \
		&& update-mime-database "${CONFIG_PACKAGE%/mime/packages/*}/mime"
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
	<mime-type type="application/x-crimson-config">
		<comment>Configuration file</comment>
		<sub-class-of type="text/plain"/>
		<glob pattern="*.ini"/>
		<glob pattern="*.conf"/>
		<glob pattern="*.cfg"/>
		<glob pattern="*.env"/>
		<glob pattern=".env"/>
		<glob pattern="*.properties"/>
		<glob pattern=".gitignore"/>
	</mime-type>
</mime-info>
XML
}

task() {
	want::packages libadwaita-1-0 libgtksourceview-5-0
	want::github_app Crimson-Org/crimson-code '-linux-{arch}\.tar\.gz$' crimson-code
	want::step "Give configuration files a type of their own" "" config_type_written write_config_type
	want::mime_default io.github.CrimsonOrg.CrimsonCode.desktop "${CODE_TYPES[@]}"
	want::mime_secondary \
		'io.github.CrimsonOrg.CrimsonText.desktop;io.github.CrimsonOrg.CrimsonText.Edit.desktop;io.github.CrimsonOrg.CrimsonCode.desktop' \
		"${MIME_TEXT_TYPES[@]}"
}
