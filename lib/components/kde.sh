# lib/components/kde.sh, KDE configuration keys

# Set one key in a KDE config file with kwriteconfig6
# The group is written the way the file shows it, so nested groups look like "Containments][1][General"
#
# --type bool is for boolean keys and --notify tells running apps about the change
want::kconfig() {
	local file="$1" group="$2" key="$3" value="$4"
	shift 4
	task::requirement "Set ${key}=${value} in ${file/#${HOME}/\~} [${group}]" "" \
		kde::_key_matches kde::_write_key "${file}" "${group}" "${key}" "${value}" "$@"
}

# Remove one key from a KDE config file
want::kconfig_absent() {
	local file="$1" group="$2" key="$3"
	task::requirement "Remove ${key} from ${file/#${HOME}/\~} [${group}]" "" \
		kde::_key_absent kde::_delete_key "${file}" "${group}" "${key}"
}

kde::_group_arguments() {
	local group="$1" part
	while [[ "${group}" == *"]["* ]]; do
		part="${group%%][*}"
		printf '%s\0%s\0' --group "${part}"
		group="${group#*][}"
	done
	printf '%s\0%s\0' --group "${group}"
}

kde::_key_matches() {
	local file="$1" group="$2" key="$3" value="$4" groups
	mapfile -d '' groups < <(kde::_group_arguments "${group}")
	[[ "$(kreadconfig6 --file "${file}" "${groups[@]}" --key "${key}")" == "${value}" ]]
}

kde::_write_key() {
	local file="$1" group="$2" key="$3" value="$4" groups
	shift 4
	mapfile -d '' groups < <(kde::_group_arguments "${group}")
	kwriteconfig6 --file "${file}" "${groups[@]}" --key "${key}" "$@" -- "${value}"
}

kde::_key_absent() {
	local file="$1" group="$2" key="$3" groups
	mapfile -d '' groups < <(kde::_group_arguments "${group}")
	[[ "$(kreadconfig6 --file "${file}" "${groups[@]}" --key "${key}" --default __absent__)" == __absent__ ]]
}

kde::_delete_key() {
	local file="$1" group="$2" key="$3" groups
	mapfile -d '' groups < <(kde::_group_arguments "${group}")
	kwriteconfig6 --file "${file}" "${groups[@]}" --key "${key}" --delete
}

# Make a running KWin read its config again
kde::reconfigure_kwin() {
	qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
}

# Make a key sequence open an app, and take it away from every other app that claims it
# Plasma 6 on Wayland only binds it after a new login, or once after Apply in System Settings, Shortcuts
#
# Every manifest in ~/.local/share/kglobalaccel registers its X-KDE-Shortcuts line at login
# So the manifest is the app's own .desktop with that line forced in, the shape KDE ships in /usr/share/kglobalaccel
#
# A leftover manifest of another app claiming the key would take it again at every login, so those are removed
want::global_shortcut() {
	local desktop_id="$1" key="$2"
	task::requirement "${key} opens $(core::desktop_name "${desktop_id}")" "" \
		kde::_shortcut_ready kde::_bind_shortcut "${desktop_id}" "${key}"
}

KDE_SHORTCUT_MANIFESTS="${HOME}/.local/share/kglobalaccel"

kde::_claims_key() {
	local file="$1" key="$2" shortcuts
	shortcuts="$(awk -F= '/^X-KDE-Shortcuts=/ { print $2; exit }' "${file}" 2>/dev/null)"
	[[ ",${shortcuts}," == *",${key},"* ]]
}

kde::_manifest() {
	local source="$1" key="$2"
	awk -v key="${key}" '
		/^X-KDE-Shortcuts=/ { next }
		/^\[/ {
			if (in_entry && !written) { print "X-KDE-Shortcuts=" key; written = 1 }
			in_entry = ($0 == "[Desktop Entry]")
		}
		{ print }
		END { if (in_entry && !written) print "X-KDE-Shortcuts=" key }
	' "${source}"
}

# Print the manifests and installed apps, other than the chosen one, that claim the key
kde::_stale_manifests() {
	local desktop_id="$1" key="$2" file
	for file in "${KDE_SHORTCUT_MANIFESTS}"/*.desktop; do
		[[ -e "${file}" && "$(basename "${file}")" != "${desktop_id}" ]] || continue
		kde::_claims_key "${file}" "${key}" && printf '%s\n' "${file}"
	done
}

kde::_competitors() {
	local desktop_id="$1" key="$2" directory file
	for directory in /usr/share/applications /usr/local/share/applications "${HOME}/.local/share/applications"; do
		for file in "${directory}"/*.desktop; do
			[[ -f "${file}" && "$(basename "${file}")" != "${desktop_id}" ]] || continue
			kde::_claims_key "${file}" "${key}" && basename "${file}"
		done
	done | sort -u
}

kde::_shortcut_ready() {
	local desktop_id="$1" key="$2" source competitor
	source="$(core::desktop_file "${desktop_id}")" || return 1
	cmp -s "${KDE_SHORTCUT_MANIFESTS}/${desktop_id}" <(kde::_manifest "${source}" "${key}") || return 1
	[[ -L "${KDE_SHORTCUT_MANIFESTS}/${desktop_id}" ]] && return 1
	[[ -z "$(kde::_stale_manifests "${desktop_id}" "${key}")" ]] || return 1
	while IFS= read -r competitor; do
		kde::_unbound "${competitor}" || return 1
	done < <(kde::_competitors "${desktop_id}" "${key}")
}

# The first field of _launch is the active key, which KDE writes as none or leaves empty when unbound
kde::_unbound() {
	local active
	active="$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$1" --key _launch)"
	[[ -n "${active}" ]] || return 1
	active="${active%%,*}"
	[[ -z "${active// /}" || "${active}" == none ]]
}

kde::_bind_shortcut() {
	local desktop_id="$1" key="$2" source manifest competitor
	source="$(core::desktop_file "${desktop_id}")" || {
		core::error "${desktop_id} is not installed"
		return 1
	}
	manifest="${KDE_SHORTCUT_MANIFESTS}/${desktop_id}"
	mkdir -p "${KDE_SHORTCUT_MANIFESTS}" && rm -f "${manifest}" || return 1
	kde::_manifest "${source}" "${key}" > "${manifest}" || return 1
	kde::_stale_manifests "${desktop_id}" "${key}" | xargs -r -d '\n' rm -f --
	while IFS= read -r competitor; do
		kwriteconfig6 --notify --file kglobalshortcutsrc --group services --group "${competitor}" \
			--key _launch "none,${key},$(core::desktop_name "${competitor}")" || return 1
	done < <(kde::_competitors "${desktop_id}" "${key}")
	kwriteconfig6 --notify --file kglobalshortcutsrc --group services --group "${desktop_id}" --key _launch --delete
	kbuildsycoca6 >/dev/null 2>&1
	return 0
}

# Keep a KWin window rule for windows of one class, with the given key=value settings
# The rule is found by its window class text, so running this again updates it instead of adding another
#
# A new rule matches that class exactly, and wmclassmatch=3 makes it a regular expression
# key:=value only seeds a value the rule lacks, for values KWin itself updates such as a remembered position
#
# A value of centered:WIDTHxHEIGHT is the position that centers such a window, worked out when the rule is written
want::kwin_rule() {
	local window_class="$1"
	shift
	task::requirement "Window rule for ${window_class}: $*" "" \
		kde::_rule_matches kde::_write_rule "${window_class}" "$@"
}

kde::_rule_id() {
	awk -v class="${1}" '
		/^\[[0-9a-f-]+\]$/ { id = substr($0, 2, length($0) - 2); next }
		/^\[/ { id = "" }
		id != "" && $0 == "wmclass=" class { print id; exit }
	' "${HOME}/.config/kwinrulesrc" 2>/dev/null
}

kde::_rule_matches() {
	local window_class="$1" id setting
	shift
	id="$(kde::_rule_id "${window_class}")"
	[[ -n "${id}" ]] || return 1
	for setting in "$@"; do
		if [[ "${setting}" == *:=* ]]; then
			[[ -n "$(kreadconfig6 --file kwinrulesrc --group "${id}" --key "${setting%%:=*}")" ]] || return 1
		else
			[[ "$(kreadconfig6 --file kwinrulesrc --group "${id}" --key "${setting%%=*}")" == "${setting#*=}" ]] \
				|| return 1
		fi
	done
}

kde::_write_rule() {
	local window_class="$1" id rules setting
	shift
	id="$(kde::_rule_id "${window_class}")"
	if [[ -z "${id}" ]]; then
		id="$(cat /proc/sys/kernel/random/uuid)"
		kwriteconfig6 --file kwinrulesrc --group "${id}" --key Description "Settings for ${window_class}" || return 1
		kwriteconfig6 --file kwinrulesrc --group "${id}" --key wmclass "${window_class}" || return 1
		kwriteconfig6 --file kwinrulesrc --group "${id}" --key wmclassmatch 1 || return 1
		rules="$(kreadconfig6 --file kwinrulesrc --group General --key rules)"
		kwriteconfig6 --file kwinrulesrc --group General --key rules "${rules:+${rules},}${id}" || return 1
		kwriteconfig6 --file kwinrulesrc --group General --key count \
			"$(( $(kreadconfig6 --file kwinrulesrc --group General --key count --default 0) + 1 ))" || return 1
	fi
	for setting in "$@"; do
		if [[ "${setting}" == *:=* ]]; then
			[[ -n "$(kreadconfig6 --file kwinrulesrc --group "${id}" --key "${setting%%:=*}")" ]] && continue
			kwriteconfig6 --file kwinrulesrc --group "${id}" --key "${setting%%:=*}" -- \
				"$(kde::_rule_value "${setting#*:=}")" || return 1
		else
			kwriteconfig6 --file kwinrulesrc --group "${id}" --key "${setting%%=*}" -- "${setting#*=}" || return 1
		fi
	done
	kde::reconfigure_kwin
}

kde::_rule_value() {
	local value="$1" size
	[[ "${value}" == centered:* ]] || { printf '%s\n' "${value}"; return; }
	size="${value#centered:}"
	kde::centered_position "${size%x*}" "${size#*x}"
}

# Print the top left corner that centers a window of the given size on the primary screen, as x,y
kde::centered_position() {
	local width="$1" height="$2" screen_width screen_height
	read -r screen_width screen_height <<< "$(kde::screen_size)"
	[[ -n "${screen_height}" ]] || return 1
	printf '%d,%d\n' "$(( (screen_width - width) / 2 ))" "$(( (screen_height - height) / 2 ))"
}

# Print the primary screen's size in pixels as width and height
kde::screen_size() {
	kscreen-doctor -j 2>/dev/null | jq -r '
		[.outputs[] | select(.enabled) | . as $output
			| ($output.modes[] | select(.id == $output.currentModeId) | .size) + {primary: ($output.priority == 1)}]
		| (map(select(.primary)) + .)[0] | "\(.width) \(.height)"'
}

# Make a comma separated list key in a KDE config file contain an item, keeping the items already there
want::kconfig_list_item() {
	local file="$1" group="$2" key="$3" item="$4"
	task::requirement "Add ${item} to ${key} in ${file/#${HOME}/\~} [${group}]" "" \
		kde::_list_has kde::_add_to_list "${file}" "${group}" "${key}" "${item}"
}

kde::_list_has() {
	local file="$1" group="$2" key="$3" item="$4" groups
	mapfile -d '' groups < <(kde::_group_arguments "${group}")
	[[ ",$(kreadconfig6 --file "${file}" "${groups[@]}" --key "${key}")," == *",${item},"* ]]
}

kde::_add_to_list() {
	local file="$1" group="$2" key="$3" item="$4" groups current
	mapfile -d '' groups < <(kde::_group_arguments "${group}")
	current="$(kreadconfig6 --file "${file}" "${groups[@]}" --key "${key}")"
	kwriteconfig6 --file "${file}" "${groups[@]}" --key "${key}" "${current:+${current},}${item}"
}

# Set a key in a panel or desktop widget's settings, the widget found by its plugin id
# The group is the path under the widget, such as "Configuration][General"
want::widget_setting() {
	local plugin="$1" group="$2" key="$3" value="$4"
	task::requirement "Set ${key} of the ${plugin##*.} widget to ${value}" "" \
		kde::_widget_setting_matches kde::_write_widget_setting "${plugin}" "${group}" "${key}" "${value}"
}

KDE_APPLETS_FILE=plasma-org.kde.plasma.desktop-appletsrc

# Print the containment and applet numbers of the first widget with this plugin, skipping widgets nested in the tray
kde::widget_location() {
	awk -v target="plugin=$1" '
		/^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ { block = $0; gsub(/[^0-9]+/, " ", block); next }
		/^\[/ { block = "" }
		block != "" && $0 == target { sub(/^ /, "", block); sub(/ $/, "", block); print block; exit }
	' "${HOME}/.config/${KDE_APPLETS_FILE}" 2>/dev/null | grep .
}

kde::_widget_group() {
	local location containment applet
	location="$(kde::widget_location "$1")" || return 1
	read -r containment applet <<< "${location}"
	printf 'Containments][%s][Applets][%s][%s\n' "${containment}" "${applet}" "$2"
}

kde::_widget_setting_matches() {
	local group
	group="$(kde::_widget_group "$1" "$2")" || return 1
	kde::_key_matches "${KDE_APPLETS_FILE}" "${group}" "$3" "$4"
}

kde::_write_widget_setting() {
	local group
	group="$(kde::_widget_group "$1" "$2")" || { core::error "there is no $1 widget"; return 1; }
	kde::_write_key "${KDE_APPLETS_FILE}" "${group}" "$3" "$4" --notify
}

# Run a Plasma desktop script, the same JavaScript System Settings and the panel templates use
kde::plasma_script() {
	qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript "$1"
}

# Offer a ready made folder in Dolphin's Create New menu
# KIO lists every .desktop in ~/Templates there, and Type=Link with a URL to a folder copies that folder
#
# The folders live in the hidden ~/Templates/.source, so they are not offered as templates themselves
want::dolphin_template() {
	local name="$1" folder="$2" comment="$3"
	task::requirement "Offer \"${name}\" in Dolphin's Create New menu" "" \
		kde::_template_written kde::_write_template "${name}" "${folder}" "${comment}"
}

kde::_template_entry() {
	printf '[Desktop Entry]\nComment=%s\nIcon=folder-development\nName=%s\nType=Link\nURL=.source/%s/\n' "$3" "$1" "$2"
}

kde::_template_written() {
	cmp -s "${HOME}/Templates/$1.desktop" <(kde::_template_entry "$@") || return 1
}

kde::_write_template() {
	mkdir -p "${HOME}/Templates" && kde::_template_entry "$@" > "${HOME}/Templates/$1.desktop"
}
