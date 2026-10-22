# lib/components/ini.sh, keys in plain INI files that are not KDE config, such as foot.ini
#
# Lines before the first [section] belong to the file's default section, main unless told otherwise
# Only the one key is replaced, so hand written lines and comments survive

want::ini_key() {
	local path="$1" section="$2" key="$3" value="$4"
	task::requirement "Set ${key}=${value} in ${path/#${HOME}/\~} [${section}]" "" \
		ini::_key_matches ini::_write_key "${path}" "${section}" "${key}" "${value}"
}

ini::read() {
	local path="$1" section="$2" key="$3"
	awk -v section="${section}" -v key="${key}" '
		BEGIN { current = "main" }
		/^[[:space:]]*\[/ { current = $0; gsub(/^[[:space:]]*\[|\].*$/, "", current); next }
		current == section {
			line = $0
			sub(/^[[:space:]]+/, "", line)
			if (line ~ ("^" key "[[:space:]]*=")) {
				sub(/^[^=]*=[[:space:]]*/, "", line)
				sub(/[[:space:]]+$/, "", line)
				print line
				exit
			}
		}
	' "${path}" 2>/dev/null
}

ini::_key_matches() {
	[[ "$(ini::read "$1" "$2" "$3")" == "$4" ]]
}

ini::_write_key() {
	local path="$1" section="$2" key="$3" value="$4" updated
	mkdir -p "$(dirname "${path}")" && touch "${path}" || return 1
	updated="$(awk -v section="${section}" -v key="${key}" -v value="${value}" '
		BEGIN { current = "main"; written = 0; seen = (section == "main") }
		/^[[:space:]]*\[/ {
			if (current == section && !written) { print key "=" value; written = 1 }
			current = $0
			gsub(/^[[:space:]]*\[|\].*$/, "", current)
			if (current == section) seen = 1
			print
			next
		}
		{
			line = $0
			sub(/^[[:space:]]+/, "", line)
			if (current == section && !written && line ~ ("^" key "[[:space:]]*=")) {
				print key "=" value
				written = 1
				next
			}
			print
		}
		END {
			if (written) exit
			if (current != section && !seen) { print ""; print "[" section "]" }
			print key "=" value
		}
	' "${path}")" || return 1
	printf '%s\n' "${updated}" > "${path}"
}

# Set several keys of one section as a single step, for app settings files with many options
want::ini_values() {
	local path="$1" section="$2"
	shift 2
	task::requirement "Set $# options in ${path/#${HOME}/\~} [${section}]" "" \
		ini::_values_match ini::_write_values "${path}" "${section}" "$@"
}

ini::_values_match() {
	local path="$1" section="$2" setting
	shift 2
	for setting in "$@"; do
		ini::_key_matches "${path}" "${section}" "${setting%%=*}" "${setting#*=}" || return 1
	done
}

ini::_write_values() {
	local path="$1" section="$2" setting
	shift 2
	for setting in "$@"; do
		ini::_write_key "${path}" "${section}" "${setting%%=*}" "${setting#*=}" || return 1
	done
}
