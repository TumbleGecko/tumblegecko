# lib/components/files.sh, files, links and folders

# Write a file whose content a function in the task prints
#
# --mode sets the file mode and --root makes it a root owned file
# --validate names a command that must accept the staged file first, and --then one to run after writing
want::file() {
	local path="$1" content_function="$2" mode=0644 owner=user validator="" after=""
	shift 2
	while (( $# )); do
		case "$1" in
			--mode) mode="$2"; shift 2 ;;
			--root) owner=root; shift ;;
			--validate) validator="$2"; shift 2 ;;
			--then) after="$2"; shift 2 ;;
			*) core::error "want::file does not know $1"; return 1 ;;
		esac
	done
	local needs=""
	[[ "${owner}" == root ]] && needs=sudo
	task::requirement "Write ${path/#${HOME}/\~}" "${needs}" \
		files::_matches files::_write "${path}" "${content_function}" "${mode}" "${owner}" "${validator}" "${after}"
}

# Some root files, such as those in /etc/sudoers.d, cannot even be looked at without root
# A plain check then cannot tell, while an install, which has root, compares them as root
files::_matches() {
	local path="$1" content_function="$2" mode="$3" owner="$4" run_as=()
	if [[ "${owner}" == root ]] && ! files::_readable "${path}"; then
		[[ "${TASK_MODE}" == apply ]] || core::root_without_asking || return "${CORE_EXIT_UNKNOWN}"
		run_as=(core::as_root)
	fi
	"${run_as[@]}" test -f "${path}" || return 1
	# sudo closes inherited file descriptors, so root reads the file and the comparison stays here
	cmp -s <("${run_as[@]}" cat "${path}") <("${content_function}") || return 1
	[[ "$("${run_as[@]}" stat -c %a "${path}")" == "${mode#0}" ]]
}

files::_readable() {
	local path="$1"
	[[ -r "${path}" ]] && return 0
	[[ -e "${path}" ]] && return 1
	[[ -x "$(dirname "${path}")" && -r "$(dirname "${path}")" ]]
}

files::_write() {
	local path="$1" content_function="$2" mode="$3" owner="$4" validator="$5" after="$6" staged status=0
	staged="$(mktemp)" || return 1
	"${content_function}" > "${staged}" || status=1
	if (( status == 0 )) && [[ -n "${validator}" ]]; then
		# Validators for root files, such as visudo, live in sbin and need root themselves
		if [[ "${owner}" == root ]]; then
			core::as_root ${validator} "${staged}" || status=1
		else
			${validator} "${staged}" || status=1
		fi
		(( status == 0 )) || core::error "${path} did not pass ${validator}"
	fi
	if (( status == 0 )); then
		if [[ "${owner}" == root ]]; then
			core::as_root install -D -o root -g root -m "${mode}" "${staged}" "${path}" || status=1
		else
			install -D -m "${mode}" "${staged}" "${path}" || status=1
		fi
	fi
	rm -f "${staged}"
	(( status == 0 )) || return 1
	[[ -z "${after}" ]] || eval "${after}"
}

# Make a symbolic link point at a target
want::symlink() {
	local link="$1" target="$2"
	task::requirement "Link ${link/#${HOME}/\~} to ${target/#${HOME}/\~}" "" \
		files::_links_to files::_link "${link}" "${target}"
}

files::_links_to() {
	[[ -L "$1" && "$(readlink "$1")" == "$2" ]]
}

files::_link() {
	local link="$1" target="$2"
	mkdir -p "$(dirname "${link}")" || return 1
	ln -sfn "${target}" "${link}"
}

want::directory() {
	local path="$1"
	task::requirement "Create ${path/#${HOME}/\~}" "" files::_is_directory files::_make_directory "${path}"
}

files::_is_directory() {
	[[ -d "$1" ]]
}

files::_make_directory() {
	mkdir -p "$1"
}

# Remove a file the task no longer wants, such as a leftover from an older setup
want::absent() {
	local path="$1" owner="${2:-user}" needs=""
	[[ "${owner}" == root ]] && needs=sudo
	task::requirement "Remove ${path/#${HOME}/\~}" "${needs}" files::_absent files::_remove "${path}" "${owner}"
}

files::_absent() {
	[[ ! -e "$1" && ! -L "$1" ]]
}

files::_remove() {
	local path="$1" owner="$2"
	if [[ "${owner}" == root ]]; then
		core::as_root rm -rf -- "${path}"
	else
		rm -rf -- "${path}"
	fi
}

# Keep one marked block inside a file that also holds other content, such as ~/.bashrc
# Only lines between its ">>> TumbleGecko <name> >>>" and "<<< TumbleGecko <name> <<<" markers are touched
want::block() {
	local path="$1" name="$2" content_function="$3"
	task::requirement "Keep the ${name} block in ${path/#${HOME}/\~}" "" \
		files::_block_matches files::_write_block "${path}" "${name}" "${content_function}"
}

files::_block() {
	local name="$1" content_function="$2"
	printf '# >>> TumbleGecko %s >>>\n' "${name}"
	"${content_function}"
	printf '# <<< TumbleGecko %s <<<\n' "${name}"
}

files::_without_block() {
	local path="$1" name="$2"
	awk -v start="# >>> TumbleGecko ${name} >>>" -v end="# <<< TumbleGecko ${name} <<<" '
		$0 == start { inside = 1; next }
		$0 == end { inside = 0; next }
		!inside { print }
	' "${path}" 2>/dev/null
}

files::_block_matches() {
	local path="$1" name="$2" content_function="$3"
	grep -Fqx "# >>> TumbleGecko ${name} >>>" "${path}" 2>/dev/null || return 1
	awk -v start="# >>> TumbleGecko ${name} >>>" -v end="# <<< TumbleGecko ${name} <<<" '
		$0 == start { inside = 1 } inside { print } $0 == end { inside = 0 }
	' "${path}" | cmp -s - <(files::_block "${name}" "${content_function}") || return 1
}

files::_write_block() {
	local path="$1" name="$2" content_function="$3" updated
	updated="$(
		files::_without_block "${path}" "${name}"
		files::_block "${name}" "${content_function}"
	)" || return 1
	mkdir -p "$(dirname "${path}")" && printf '%s\n' "${updated}" > "${path}"
}
