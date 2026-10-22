# lib/components/mime.sh, default apps for file types

# File types can be written out, or read from installed apps when the step runs, so a list never goes stale
# @app.desktop means every type that app declares, and @app.desktop:^video/ only those matching the regex
# A regex that starts with ! keeps the types that do not match, such as @app.desktop:!photoshop
#
# @app.desktop+other.desktop:regex means only types both apps declare

# Plain text, Markdown, tables and logs, which the text viewer opens and editors offer to open
MIME_TEXT_TYPES=(
	text/plain text/markdown text/x-markdown text/x-readme text/csv text/tab-separated-values text/x-log
	application/x-zerosize
)

# Make an app the default for file types, by the id of its .desktop file
want::mime_default() {
	local desktop_id="$1"
	shift
	task::requirement "Open $(mime::_describe "$@") with $(core::desktop_name "${desktop_id}")" "" \
		mime::_defaults_are mime::_set_defaults "${desktop_id}" "$@"
}

# Put apps right after the default in the Open With list, in order, leaving out those not installed
# Dolphin opens the first one after the default on middle-click, and the next on Shift and middle-click
want::mime_secondary() {
	local apps="$1" app names=""
	shift
	for app in ${apps//;/ }; do
		names+="${names:+, then }$(core::desktop_name "${app}")"
	done
	task::requirement "Offer ${names} first in Open With for $(mime::_describe "$@")" "" \
		mime::_associations_start_with mime::_set_associations "${apps}" "$@"
}

mime::_describe() {
	local apps app names=()
	if (( $# == 1 )) && [[ "$1" == @* ]]; then
		apps="${1#@}"
		for app in $(tr + " " <<< "${apps%%:*}"); do
			names+=("$(core::desktop_name "${app}")")
		done
		if [[ "${apps%%:*}" == *+* ]]; then
			printf 'the file types both %s and %s handle\n' "${names[0]}" "${names[1]}"
			return
		fi
		printf 'the file types %s handles\n' "${names[*]}"
		return
	fi
	(( $# == 1 )) && { printf '%s\n' "$1"; return; }
	printf '%s file types\n' "$#"
}

# Print the file types the arguments stand for, failing when an app they name is not installed
# Each type comes with its older names, since KDE merges the lists under every name of a type
# Without them a type asked about by an old name, such as text/x-shellscript, keeps the default of its parent type
mime::expand_types() {
	local selector apps pattern exclude app first types app_types
	for selector in "$@"; do
		if [[ "${selector}" != @* ]]; then
			printf '%s\n' "${selector}" | mime::_with_aliases
			continue
		fi
		selector="${selector#@}"
		apps="${selector%%:*}"
		pattern=.
		exclude=""
		[[ "${selector}" == *:* ]] && pattern="${selector#*:}"
		if [[ "${pattern}" == '!'* ]]; then
			exclude="${pattern#!}"
			pattern=.
		fi
		first=1
		types=""
		for app in ${apps//+/ }; do
			app_types="$(mime::types_of "${app}" "${pattern}")" || return 1
			if (( first )); then
				types="${app_types}"
				first=0
			else
				types="$(comm -12 <(sort <<< "${types}") <(sort <<< "${app_types}"))"
			fi
		done
		[[ -n "${types}" ]] || return 1
		# The exclusion comes after the older names are added, or a name that differs would bring a type back
		printf '%s\n' "${types}" | mime::_with_aliases | grep -v -E -- "${exclude:-^\$}" || true
	done | sort -u
}

mime::_with_aliases() {
	local aliases=/usr/share/mime/aliases type canonical
	while IFS= read -r type; do
		printf '%s\n' "${type}"
		[[ -r "${aliases}" ]] || continue
		# Each line is an old name followed by the current one, and either may be what a task wrote
		canonical="$(awk -v type="${type}" '$1 == type { print $2; exit }' "${aliases}")"
		canonical="${canonical:-${type}}"
		printf '%s\n' "${canonical}"
		awk -v canonical="${canonical}" '$2 == canonical { print $1 }' "${aliases}"
	done
}

mime::_defaults_are() {
	local desktop_id="$1" types type
	shift
	types="$(mime::expand_types "$@")" || return 1
	while IFS= read -r type; do
		[[ "$(xdg-mime query default "${type}" 2>/dev/null)" == "${desktop_id}" ]] || return 1
	done <<< "${types}"
}

# Expand file types for a change, and say why when an app they come from is missing
mime::_types_to_change() {
	mime::expand_types "$@" && return 0
	core::error "an app these file types come from is not installed"
	return 1
}

mime::_set_defaults() {
	local desktop_id="$1" types type
	shift
	types="$(mime::_types_to_change "$@")" || return 1
	update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null
	while IFS= read -r type; do
		xdg-mime default "${desktop_id}" "${type}" || return 1
		# KDE ranks its own list above mimeapps.list, so an older default written there has to follow
		if [[ -n "$(kreadconfig6 --file kde-mimeapps.list --group "Default Applications" --key "${type}")" ]]; then
			kwriteconfig6 --file kde-mimeapps.list --group "Default Applications" --key "${type}" "${desktop_id};" || return 1
		fi
	done <<< "${types}"
}

# The apps from a list that are installed, in the same order and form
mime::_installed_apps() {
	local app installed=""
	for app in ${1//;/ }; do
		core::desktop_file "${app}" >/dev/null && installed+="${installed:+;}${app}"
	done
	printf '%s\n' "${installed}"
}

mime::_associations_start_with() {
	local apps types type kde_list
	apps="$(mime::_installed_apps "$1")"
	shift
	[[ -n "${apps}" ]] || return 0
	types="$(mime::expand_types "$@")" || return 1
	while IFS= read -r type; do
		[[ "$(kreadconfig6 --file mimeapps.list --group "Added Associations" --key "${type}")" == "${apps}"* ]] \
			|| return 1
		# KDE's own list ranks above that one, so where it names a type its apps have to match as well
		kde_list="$(kreadconfig6 --file kde-mimeapps.list --group "Default Applications" --key "${type}")"
		[[ -z "${kde_list}" || "${kde_list}" == "${apps}"* ]] || return 1
	done <<< "${types}"
}

mime::_set_associations() {
	local apps types type
	apps="$(mime::_installed_apps "$1")"
	shift
	[[ -n "${apps}" ]] || return 0
	types="$(mime::_types_to_change "$@")" || return 1
	while IFS= read -r type; do
		kwriteconfig6 --file mimeapps.list --group "Added Associations" --key "${type}" "${apps}" || return 1
		if [[ -n "$(kreadconfig6 --file kde-mimeapps.list --group "Default Applications" --key "${type}")" ]]; then
			kwriteconfig6 --file kde-mimeapps.list --group "Default Applications" --key "${type}" "${apps};" || return 1
		fi
	done <<< "${types}"
	kbuildsycoca6 >/dev/null 2>&1
	return 0
}

# Print the file types an installed .desktop file declares, optionally only those matching an extended regex
mime::types_of() {
	local desktop_id="$1" pattern="${2:-.}" file
	file="$(core::desktop_file "${desktop_id}")" || return 1
	sed -n 's/^MimeType=//p' "${file}" | tr ';' '\n' | grep -E -- "${pattern}" | grep .
}

# Register a hidden app that opens file types, and make it their default
# exec is the whole Exec line, such as "~/.local/bin/mount-iso %f"
want::handler() {
	local desktop_id="$1" name="$2" icon="$3" exec_line="$4"
	shift 4
	task::requirement "Register ${name} for $(mime::_describe "$@")" "" \
		mime::_handler_written mime::_write_handler "${desktop_id}" "${name}" "${icon}" "${exec_line}" "$@"
	want::mime_default "${desktop_id}" "$@"
}

mime::_handler_entry() {
	local name="$2" icon="$3" exec_line="$4"
	shift 4
	printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\n' "${name}" "${exec_line}" "${icon}"
	printf 'Terminal=false\nNoDisplay=true\nMimeType=%s\n' "$(printf '%s;' "$@")"
}

mime::_handler_written() {
	cmp -s "${HOME}/.local/share/applications/$1" <(mime::_handler_entry "$@") || return 1
}

mime::_write_handler() {
	local directory="${HOME}/.local/share/applications"
	mkdir -p "${directory}" && mime::_handler_entry "$@" > "${directory}/$1" || return 1
	update-desktop-database "${directory}" 2>/dev/null
	# KIO looks handlers up in ksycoca, which only sees a new .desktop file after a rebuild
	kbuildsycoca6 >/dev/null 2>&1
	return 0
}
