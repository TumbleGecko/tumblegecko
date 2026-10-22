# lib/components/apps.sh, AppImages, autostart entries and app settings files

APPS_APPIMAGE_DIR="${HOME}/Applications"
APPS_MENU_DIR="${HOME}/.local/share/applications"
APPS_ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"
APPS_AUTOSTART_DIR="${HOME}/.config/autostart"


# ============================================================================
# AppImages

# Install the newest AppImage a GitHub project releases, and add it to the app menu
# The menu entry and icon come from the AppImage's embedded .desktop, with Exec and Icon pointed at the local copy
want::appimage() {
	local repository="$1" pattern="$2" name="$3"
	local appimage="${APPS_APPIMAGE_DIR}/${name}.AppImage"
	want::github_file "${repository}" "${pattern}" "${appimage}"
	task::requirement "Add ${name} to the app menu" "" \
		apps::_menu_entry_matches apps::_write_menu_entry "${appimage}" "${name}"
}

# Unpack only the AppImage's .desktop file and icons into a fresh directory and print it
# --appimage-extract takes a pattern, so the rest of the image is left alone
apps::_appimage_metadata() {
	local appimage="$1" directory
	directory="$(mktemp -d)" || return 1
	(
		cd "${directory}" || exit 1
		"${appimage}" --appimage-extract '*.desktop' || exit 1
		icon="$(sed -n 's/^Icon=//p' squashfs-root/*.desktop | head -1)"
		"${appimage}" --appimage-extract "*${icon}.png"
		"${appimage}" --appimage-extract "*${icon}.svg"
	) >/dev/null 2>&1
	printf '%s\n' "${directory}/squashfs-root"
}

# Print the best icon an unpacked AppImage holds, a scalable one first, then the largest picture
apps::_best_icon() {
	local metadata="$1"
	find -L "${metadata}" -name '*.svg' -print -quit | grep . && return 0
	find -L "${metadata}" -name '*.png' -printf '%s %p\n' | sort -n | tail -1 | cut -d' ' -f2-
}

apps::_menu_entry() {
	local appimage="$1" name="$2" metadata embedded status=0
	metadata="$(apps::_appimage_metadata "${appimage}")" || return 1
	embedded="$(find "${metadata}" -maxdepth 1 -name '*.desktop' | head -1)"
	if [[ -n "${embedded}" ]]; then
		awk -v appimage="${appimage}" -v name="${name}" '
			/^\[/ { entry = ($0 == "[Desktop Entry]") }
			/^(TryExec|X-AppImage-[^=]*)=/ { next }
			/^Exec=/ { sub(/^Exec=[^ ]*/, "Exec=" appimage) }
			entry && /^Icon=/ { $0 = "Icon=" name }
			{ print }
		' "${embedded}"
	else
		core::error "${appimage} has no embedded .desktop file"
		status=1
	fi
	rm -rf "$(dirname "${metadata}")"
	return "${status}"
}

apps::_menu_entry_matches() {
	local appimage="$1" name="$2"
	[[ -f "${APPS_ICON_DIR}/${name}.png" || -f "${APPS_ICON_DIR}/${name}.svg" ]] || return 1
	cmp -s "${APPS_MENU_DIR}/${name}.desktop" <(apps::_menu_entry "${appimage}" "${name}") || return 1
}

apps::_write_menu_entry() {
	local appimage="$1" name="$2" metadata icon extension
	mkdir -p "${APPS_MENU_DIR}" "${APPS_ICON_DIR}" || return 1
	apps::_menu_entry "${appimage}" "${name}" > "${APPS_MENU_DIR}/${name}.desktop" || return 1
	metadata="$(apps::_appimage_metadata "${appimage}")" || return 1
	icon="$(apps::_best_icon "${metadata}")"
	[[ -n "${icon}" ]] || { core::error "${appimage} holds no icon"; return 1; }
	extension=png
	[[ "$(file -b --mime-type "${icon}")" == image/svg* ]] && extension=svg
	cp -f "${icon}" "${APPS_ICON_DIR}/${name}.${extension}"
	rm -rf "$(dirname "${metadata}")"
	update-desktop-database "${APPS_MENU_DIR}" 2>/dev/null
	kbuildsycoca6 >/dev/null 2>&1
	return 0
}


# ============================================================================
# Autostart

# Start an app when you log in the way System Settings does, with a copy of the app's own .desktop entry
# Extra arguments go after its command, and its field codes such as %U are dropped since there is nothing to open
want::autostart() {
	local desktop_id="$1"
	shift
	task::requirement "Start $(core::desktop_name "${desktop_id}") when you log in${*:+ with $*}" "" \
		apps::_autostart_matches apps::_write_autostart "${desktop_id}" "$@"
}

apps::_autostart_entry() {
	local desktop_id="$1" source
	shift
	source="$(core::desktop_file "${desktop_id}")" || return 1
	awk -v arguments="$*" '
		/^\[/ { entry = ($0 == "[Desktop Entry]") }
		!entry { next }
		/^(Exec|TryExec|Hidden|X-GNOME-Autostart-enabled)=/ && !/^Exec=/ { next }
		/^Exec=/ { gsub(/ %[fFuUdDnNickvm]/, ""); sub(/ --$/, ""); if (arguments != "") $0 = $0 " " arguments }
		{ print }
	' "${source}"
}

# System Settings, Autostart, turns an entry off by adding Hidden=true, so that counts as not set up
apps::_autostart_matches() {
	cmp -s "${APPS_AUTOSTART_DIR}/$1" <(apps::_autostart_entry "$@") || return 1
}

apps::_write_autostart() {
	mkdir -p "${APPS_AUTOSTART_DIR}" && apps::_autostart_entry "$@" > "${APPS_AUTOSTART_DIR}/$1"
}


# Start a command when you log in, for apps that have no .desktop file of their own to copy
want::autostart_command() {
	local name="$1" command_line="$2"
	task::requirement "Start ${name} when you log in" "" \
		apps::_command_autostart_matches apps::_write_command_autostart "${name}" "${command_line}"
}

apps::_command_autostart_file() {
	printf '%s/%s.desktop\n' "${APPS_AUTOSTART_DIR}" "$(tr '[:upper:] ' '[:lower:]-' <<< "$1")"
}

apps::_command_autostart_entry() {
	printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nTerminal=false\nNoDisplay=true\n' "$1" "$2"
}

apps::_command_autostart_matches() {
	cmp -s "$(apps::_command_autostart_file "$1")" <(apps::_command_autostart_entry "$@") || return 1
}

apps::_write_command_autostart() {
	mkdir -p "${APPS_AUTOSTART_DIR}" && apps::_command_autostart_entry "$@" > "$(apps::_command_autostart_file "$1")"
}


# ============================================================================
# JSON settings

# Set one value in an app's JSON settings file, keeping everything else
# The path is jq syntax such as .defaultSettings.startInTray, and the value is JSON such as true
want::json_value() {
	local path="$1" key="$2" value="$3"
	task::requirement "Set ${key} to ${value} in ${path/#${HOME}/\~}" "" \
		apps::_json_matches apps::_write_json "${path}" "${key}" "${value}"
}

apps::_json_matches() {
	jq -e --argjson value "$3" "$2 == \$value" "$1" >/dev/null 2>&1
}

apps::_write_json() {
	local path="$1" key="$2" value="$3" updated
	mkdir -p "$(dirname "${path}")" || return 1
	[[ -s "${path}" ]] || printf '{}\n' > "${path}"
	updated="$(jq --argjson value "${value}" "${key} = \$value" "${path}")" || return 1
	printf '%s\n' "${updated}" > "${path}"
}


# ============================================================================
# Default browser

want::default_browser() {
	local desktop_id="$1"
	task::requirement "Use $(core::desktop_name "${desktop_id}") as the web browser" "" \
		apps::_is_default_browser apps::_set_default_browser "${desktop_id}"
}

apps::_is_default_browser() {
	[[ "$(xdg-settings get default-web-browser 2>/dev/null)" == "$1" ]]
}

apps::_set_default_browser() {
	xdg-settings set default-web-browser "$1"
}


# ============================================================================
# GNOME settings

# Set a gsettings key, which GTK and libadwaita apps read
want::gsettings() {
	local schema="$1" key="$2" value="$3"
	task::requirement "Set ${schema} ${key} to ${value}" "" apps::_gsettings_match apps::_set_gsettings "$@"
}

apps::_gsettings_match() {
	[[ "$(gsettings get "$1" "$2" 2>/dev/null)" == "$3" || "$(gsettings get "$1" "$2" 2>/dev/null)" == "'$3'" ]]
}

apps::_set_gsettings() {
	gsettings set "$1" "$2" "$3"
}
