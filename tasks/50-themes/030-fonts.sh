#!/usr/bin/env bash
# name:     Fonts
# summary:  Segoe UI Variable for the interface, JetBrains Mono Nerd Font for code, and Japanese, Chinese, Korean and emoji fonts so no text shows as boxes.
# default:  on
#
# Segoe UI Variable comes from Microsoft's own download, which publishes no checksum
# JetBrains Mono comes from the newest Nerd Fonts release
#
# Both go into /usr/share/fonts, and the family names were checked with fc-scan against the files on 2026-05-26
# KDE stores each font as Qt 6's 19 field QFont text, written here the way System Settings writes it
#
# The style name picks an optical size, "Regular Small" for body text and "Regular Display" for headings
# Sub-pixel rendering is off, anti-aliasing on and hinting slight, in the fontconfig file System Settings uses

UI_FONT="Segoe UI Variable"
CODE_FONT="JetBrainsMono Nerd Font Mono"
SEGOE=/usr/share/fonts/SegoeUI
FONTS_CONF="${HOME}/.config/fontconfig/fonts.conf"

# family, point size, style name
qfont() {
	printf '%s,%s,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,%s,0,0' "$1" "$2" "${3:-}"
}

segoe_installed() {
	fc-scan --format '%{family[0]}\n' "${SEGOE}/SegoeUI-VF.ttf" 2>/dev/null | grep -Fxq "${UI_FONT}"
}

install_segoe() {
	local archive status=0
	archive="$(mktemp)" || return 1
	curl -fsSL --max-time 300 -o "${archive}" https://aka.ms/SegoeUIVariable \
		&& core::as_root mkdir -p "${SEGOE}" && core::as_root unzip -o -q "${archive}" -d "${SEGOE}" || status=1
	rm -f "${archive}"
	return "${status}"
}

rendering_set() {
	local setting
	for setting in 'rgba <const>none' 'hintstyle <const>hintslight' 'antialias <bool>true' 'hinting <bool>true'; do
		grep -A1 "name=\"${setting%% *}\"" "${FONTS_CONF}" 2>/dev/null | grep -qF "${setting#* }<" || return 1
	done
}

set_rendering() {
	local setting name value kind match
	if [[ ! -f "${FONTS_CONF}" ]]; then
		mkdir -p "$(dirname "${FONTS_CONF}")" || return 1
		printf "<?xml version='1.0'?>\n<!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>\n%s\n%s\n" \
			'<fontconfig>' '</fontconfig>' > "${FONTS_CONF}"
	fi
	for setting in rgba:const:none hintstyle:const:hintslight antialias:bool:true hinting:bool:true; do
		IFS=: read -r name kind value <<< "${setting}"
		if grep -q "name=\"${name}\"" "${FONTS_CONF}"; then
			sed -i -E "/name=\"${name}\"/{n;s|<${kind}>[^<]*</${kind}>|<${kind}>${value}</${kind}>|}" "${FONTS_CONF}"
		else
			match=" <match target=\"font\">\n  <edit mode=\"assign\" name=\"${name}\">\n"
			match+="   <${kind}>${value}</${kind}>\n  </edit>\n </match>"
			sed -i "s|</fontconfig>|${match}\n</fontconfig>|" "${FONTS_CONF}"
		fi
	done
}

refresh_font_cache() {
	fc-cache -f && core::as_root fc-cache -f -s
}

task() {
	want::packages --no-recommends unzip google-noto-sans-cjk-fonts google-noto-serif-jp-fonts \
		google-noto-coloremoji-fonts
	want::step "Install Segoe UI Variable" "sudo network" segoe_installed install_segoe
	want::github_archive ryanoasis/nerd-fonts '^JetBrainsMono\.tar\.xz$' /usr/share/fonts/JetBrainsMono --root
	want::kconfig kdeglobals General font "$(qfont "${UI_FONT}" 11 'Regular Small')" --notify
	want::kconfig kdeglobals General fixed "$(qfont "${CODE_FONT}" 13)" --notify
	want::kconfig kdeglobals General menuFont "$(qfont "${UI_FONT}" 11 'Regular Display')" --notify
	want::kconfig kdeglobals General toolBarFont "$(qfont "${UI_FONT}" 11 'Regular Display')" --notify
	want::kconfig kdeglobals General smallestReadableFont "$(qfont "${UI_FONT}" 9 'Regular Small')" --notify
	want::kconfig kdeglobals General desktopFont "$(qfont "${UI_FONT}" 10.5 'Regular Display')" --notify
	want::kconfig kdeglobals WM activeFont "$(qfont "${UI_FONT}" 11 'Regular Display')" --notify
	want::step "Turn off sub-pixel rendering and use slight hinting" "" rendering_set set_rendering
	on_change refresh_font_cache
}
