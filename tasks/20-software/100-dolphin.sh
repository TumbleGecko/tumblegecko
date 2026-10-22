#!/usr/bin/env bash
# name:     Dolphin
# summary:  Opens at home, remembers each folder's view, puts newest files first in Downloads and Pictures, pins ~/Projects in Places and shows git status.
# default:  on
# group:    Files and text
#
# GlobalViewProps=false is what "remember display style for each folder" stores, the inverse of the checkbox
# Changes show the next time Dolphin starts
#
# Places live in ~/.local/share/user-places.xbel, the XBEL file KDE's KFilePlacesModel keeps
# KDE creates it in every Plasma session, so a missing file means something is wrong and the task refuses to make one
#
# The edited copy must pass xmllint before it replaces the original, which is kept as user-places.xbel.bak
# The folder icon is [Desktop Entry] Icon in the folder's own .directory file, what Dolphin's icon picker writes
#
# Dolphin keeps a folder's view settings in its user.kde.fm.viewproperties#1 extended attribute as a small INI text
# Seen with Dolphin 26.08, it reads the attribute and no longer a .directory [Dolphin] group
#
# SortOrder 1 is descending
# The folder icon stays in .directory, the freedesktop place for it
#
# dolphin-plugins is KDE's own version control integration, which Dolphin enables by the plugin name Git
# Source is enabledPlugins.contains(p.name()) in dolphin versioncontrolobserver.cpp
#
# Its "Show Local Changes" runs git difftool --dir-diff, which waits on a terminal unless difftool.prompt is false
# kompare can only diff and kdiff3 can merge, so they become diff.tool and merge.tool unless you chose others

PROJECTS="${HOME}/Projects"
PLACES="${HOME}/.local/share/user-places.xbel"

bookmark_present() {
	grep -Fq "href=\"file://${PROJECTS}\"" "${PLACES}" 2>/dev/null
}

add_bookmark() {
	local edited block
	[[ -s "${PLACES}" ]] && grep -q '</xbel>' "${PLACES}" || {
		core::error "${PLACES} is missing or malformed, open Dolphin once and run this again"
		return 1
	}
	block="$(cat <<BOOKMARK
 <bookmark href="file://${PROJECTS}">
  <title>Projects</title>
  <info>
   <metadata owner="http://freedesktop.org">
    <bookmark:icon name="folder-symbolic"/>
   </metadata>
   <metadata owner="http://www.kde.org">
    <ID>$(date +%s)/0</ID>
   </metadata>
  </info>
 </bookmark>
BOOKMARK
)"
	edited="$(mktemp "${PLACES}.XXXXXX")" || return 1
	awk -v block="${block}" -v anchor="file://${HOME}/Music" '
		index($0, "href=\"" anchor "\"") { print block; placed = 1 }
		/<\/xbel>/ && !placed { print block; placed = 1 }
		{ print }
	' "${PLACES}" > "${edited}"
	if ! xmllint --noout "${edited}" 2>/dev/null; then
		rm -f "${edited}"
		core::error "the edited places file was not valid XML, the original is untouched"
		return 1
	fi
	cp -f "${PLACES}" "${PLACES}.bak" && chmod 0644 "${edited}" && mv "${edited}" "${PLACES}"
}

NEWEST_FIRST=("${HOME}/Downloads" "${HOME}/Pictures" "${HOME}/Pictures/Screenshots")
VIEW_ATTRIBUTE='user.kde.fm.viewproperties#1'
WANTED_VIEW=(SortRole=modificationtime SortOrder=1)

view_settings() {
	getfattr --only-values -n "${VIEW_ATTRIBUTE}" "$1" 2>/dev/null
}

newest_first() {
	local folder="$1" setting settings
	settings="$(view_settings "${folder}")"
	for setting in "${WANTED_VIEW[@]}"; do
		grep -qx -- "${setting}" <<< "${settings}" || return 1
	done
}

# Keep the folder's other view settings and replace only the sort ones
sort_newest_first() {
	local folder="$1" settings setting
	settings="$(view_settings "${folder}")"
	[[ -n "${settings}" ]] || settings=$'[Dolphin]\nVersion=4'
	for setting in "${WANTED_VIEW[@]}"; do
		settings="$(grep -v "^${setting%%=*}=" <<< "${settings}")"$'\n'"${setting}"
	done
	setfattr -n "${VIEW_ATTRIBUTE}" -v "${settings}"$'\n' "${folder}"
}

task() {
	want::kconfig dolphinrc General ConfirmClosingMultipleTabs false
	want::kconfig dolphinrc General ShowStatusBar FullWidth
	want::kconfig dolphinrc General ShowSelectionToggle false
	want::kconfig dolphinrc General AutoExpandFolders true
	want::kconfig dolphinrc General GlobalViewProps false
	want::kconfig dolphinrc General RememberOpenedTabs false
	want::kconfig dolphinrc General ModifiedStartupSettings true
	want::kconfig dolphinrc General UseTabForSwitchingSplitView true
	want::kconfig dolphinrc General HomeUrl "file://${HOME}"
	want::kconfig dolphinrc IconsMode IconSize 64
	want::directory "${PROJECTS}"
	want::kconfig "${PROJECTS}/.directory" "Desktop Entry" Icon folder-development
	want::step "Pin Projects in Dolphin's Places" "" bookmark_present add_bookmark
	local folder
	for folder in "${NEWEST_FIRST[@]}"; do
		want::directory "${folder}"
		want::step "Sort ${folder/#${HOME}/\~} newest first" "" newest_first sort_newest_first "${folder}"
	done
	want::kconfig "${HOME}/Pictures/.directory" "Desktop Entry" Icon folder-pictures
	want::kconfig "${HOME}/Pictures/Screenshots/.directory" "Desktop Entry" Icon folder-pictures
	want::packages --no-recommends dolphin-plugins kdiff3 kompare
	want::kconfig_list_item dolphinrc VersionControl enabledPlugins Git
	want::git_config diff.tool kompare --unless-set
	want::git_config merge.tool kdiff3 --unless-set
	want::git_config difftool.prompt false
	restart::if_changed "Dolphin shows these after you open it again"
}
