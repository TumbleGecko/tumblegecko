#!/usr/bin/env bash
# name:     Nothing theme
# summary:  Dark Nothing colors with a purple accent, Vimix icons, the Nothing wallpaper, and only minimize and close on title bars.
# default:  on
#
# Source https://gitlab.com/jomada/nothing, followed at its newest main commit
# Three color schemes are derived from Nothing.colors, and Gecko Remix with frameContrast 0.05 is the one applied
#
# The Dark and Darcula Titlebar variants are for window rules such as foot's
# The Plasma style stays default and the decoration Breeze, so the Nothing Plasma and Aurorae themes go unused
#
# Title bar buttons are letters from s_buttonNames in kwin/src/decorations/settings.cpp
# E is exclude from capture, I minimize and X close, and maximize is left out on purpose
#
# The icons need the Vimix task first

SOURCE="${HOME}/.local/share/tumblegecko/sources/nothing"
SHARE="${HOME}/.local/share"
COLOR_SCHEMES="${SHARE}/color-schemes"
APPLIED_SCHEME=NothingGeckoRemix
ACCENT=184,117,220

# Copy Nothing.colors under a new name, then apply "group key value" triples to it
derive_scheme() {
	local file="${COLOR_SCHEMES}/$1.colors" display_name="$2"
	shift 2
	cp "${COLOR_SCHEMES}/Nothing.colors" "${file}" || return 1
	kwriteconfig6 --file "${file}" --group General --key Name "${display_name}"
	kwriteconfig6 --file "${file}" --group General --key ColorScheme "$(basename "${file}" .colors)"
	while (( $# >= 3 )); do
		kwriteconfig6 --file "${file}" --group "$1" --key "$2" "$3" || return 1
		shift 3
	done
}

titlebar_colors() {
	printf 'WM %s %s ' activeBackground "$1" activeBlend "$1" inactiveBackground "$1" inactiveBlend "$1"
	printf 'KDE frameContrast 0.05'
}

theme_files_current() {
	[[ -f "${COLOR_SCHEMES}/${APPLIED_SCHEME}.colors" ]] \
		&& cmp -s "${SOURCE}/.tumblegecko-commit" "${SHARE}/plasma/desktoptheme/Nothing/.tumblegecko-commit" || return 1
}

install_theme_files() {
	mkdir -p "${SHARE}"/{plasma/desktoptheme,plasma/look-and-feel,aurorae/themes,wallpapers,konsole} \
		"${COLOR_SCHEMES}" || return 1
	cp -r "${SOURCE}/Nothing" "${SHARE}/plasma/desktoptheme/" \
		&& cp -r "${SOURCE}/aurorae/Nothing" "${SHARE}/aurorae/themes/" \
		&& cp "${SOURCE}"/color-schemes/Nothing{,Lightly}.colors "${COLOR_SCHEMES}/" \
		&& cp "${SOURCE}/konsole/Nothing.colorscheme" "${SHARE}/konsole/" \
		&& cp -r "${SOURCE}/look-and-feel/Nothing" "${SHARE}/plasma/look-and-feel/" \
		&& cp -r "${SOURCE}"/wallpapers/Nothing{1,2,3} "${SHARE}/wallpapers/" || return 1
	derive_scheme NothingGeckoRemix "Nothing Gecko Remix" KDE frameContrast 0.05 || return 1
	# shellcheck disable=SC2046
	derive_scheme NothingDarkTitlebar "Nothing Dark Titlebar" $(titlebar_colors 12,13,14) || return 1
	# shellcheck disable=SC2046
	derive_scheme NothingDarculaTitlebar "Nothing Darcula Titlebar" $(titlebar_colors 38,39,48) || return 1
	cp "${SOURCE}/.tumblegecko-commit" "${SHARE}/plasma/desktoptheme/Nothing/"
}

scheme_applied() {
	[[ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" == "${APPLIED_SCHEME}" ]]
}

apply_scheme() {
	plasma-apply-colorscheme "${APPLIED_SCHEME}"
}

plasma_style_applied() {
	[[ "$(kreadconfig6 --file plasmarc --group Theme --key name)" == default ]]
}

apply_plasma_style() {
	plasma-apply-desktoptheme default
}

# The first picture of the Nothing1 wallpaper, wherever Plasma keeps the desktop's wallpaper setting
wallpaper_image() {
	find "${SHARE}/wallpapers/Nothing1/contents/images" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) \
		| sort | head -1
}

wallpaper_applied() {
	grep -q "^Image=.*wallpapers/Nothing1" "${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null
}

apply_wallpaper() {
	plasma-apply-wallpaperimage "$(wallpaper_image)"
}

task() {
	want::git_branch https://gitlab.com/jomada/nothing.git main "${SOURCE}"
	want::step "Install the Nothing themes, color schemes and wallpapers" "" theme_files_current install_theme_files
	want::step "Use the Nothing Gecko Remix colors" "" scheme_applied apply_scheme
	want::step "Use the default Plasma style" "" plasma_style_applied apply_plasma_style
	want::step "Use the Nothing wallpaper" "" wallpaper_applied apply_wallpaper
	want::kconfig kdeglobals General AccentColor "${ACCENT}" --notify
	want::kconfig kdeglobals General LastUsedCustomAccentColor "${ACCENT}"
	want::kconfig kdeglobals KDE widgetStyle Breeze --notify
	want::kconfig kdeglobals KDE ShowIconsInMenuItems false --notify
	want::kconfig kdeglobals KDE ShowIconsOnPushButtons false --notify
	want::kconfig kwinrc org.kde.kdecoration2 library org.kde.breeze
	want::kconfig kwinrc org.kde.kdecoration2 ButtonsOnLeft E
	want::kconfig kwinrc org.kde.kdecoration2 ButtonsOnRight IX
	want::kconfig kdeglobals Icons Theme Vimix-dark --notify
	on_change kde::reconfigure_kwin
}
