# lib/components/github.sh, install things from a project's newest GitHub release
#
# A task names the repository and a regex for the file it wants, never a version or URL
# {arch} in a pattern stands for this machine's processor, such as x86_64
#
# Every download is checked against GitHub's sha256 digest for the file, or a checksum file the release publishes
# --no-checksum is for projects that publish none, which leaves only the HTTPS download from GitHub
#
# --prereleases also counts pre-releases, and the newest release holding a matching file wins

GITHUB_API="https://api.github.com"
GITHUB_TIMEOUT_SECONDS=30
GITHUB_DOWNLOAD_TIMEOUT_SECONDS=1800
# Release lookups are reused for this long, so one setup run asks GitHub about each project once
GITHUB_CACHE_SECONDS=600
GITHUB_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/tumblegecko/github"
GITHUB_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/tumblegecko/installed"


# ============================================================================
# Releases

# A GH_TOKEN in the environment raises GitHub's limit of 60 lookups an hour
# Nothing reads a stored login, that would unlock the keyring and ask for a password
github::_curl() {
	curl --fail --silent --show-error --location --max-time "${GITHUB_TIMEOUT_SECONDS}" \
		-H 'Accept: application/vnd.github+json' \
		${GH_TOKEN:+-H "Authorization: Bearer ${GH_TOKEN}"} "$@"
}

# Split the shared options out of a component's arguments
# Sets source_flags to a word list such as "prereleases no-checksum" and leaves the rest in remaining_options
github::_split_options() {
	source_flags=""
	remaining_options=()
	while (( $# )); do
		case "$1" in
			--prereleases) source_flags+=" prereleases" ;;
			--no-checksum) source_flags+=" no-checksum" ;;
			*) remaining_options+=("$1") ;;
		esac
		shift
	done
}

github::_has_flag() {
	[[ " $1 " == *" $2 "* ]]
}

# Print the release a source points at as JSON, the newest stable one unless pre-releases count
github::release() {
	local repository="$1" pattern="$2" flags="$3" cache_key cache_file release
	pattern="${pattern//\{arch\}/$(uname -m)}"
	cache_key="$(printf '%s %s %s' "${repository}" "${pattern}" "${flags}" | sha1sum | cut -c1-16)"
	cache_file="${GITHUB_CACHE_DIR}/${cache_key}.json"
	if [[ -n "$(find "${cache_file}" -newermt "-${GITHUB_CACHE_SECONDS} seconds" 2>/dev/null)" ]]; then
		cat "${cache_file}"
		return 0
	fi
	if github::_has_flag "${flags}" prereleases; then
		release="$(github::_highest_release "${repository}" "${pattern}")" || return 1
	else
		release="$(github::_curl "${GITHUB_API}/repos/${repository}/releases/latest")" || return 1
	fi
	[[ -n "${release}" ]] || return 1
	mkdir -p "${GITHUB_CACHE_DIR}"
	printf '%s\n' "${release}" > "${cache_file}"
	printf '%s\n' "${release}"
}

# Some projects publish several series side by side, so the highest version wins rather than the latest published
github::_highest_release() {
	local repository="$1" pattern="$2" releases highest
	local matching='[.[] | select((.draft | not) and any(.assets[]; .name | test($pattern)))]'
	releases="$(github::_curl "${GITHUB_API}/repos/${repository}/releases?per_page=100" \
		| jq -c --arg pattern "${pattern}" "${matching}")" || return 1
	highest="$(jq -r '.[].tag_name' <<< "${releases}" | while IFS= read -r tag; do
		printf '%s\t%s\n' "$(core::version_from_text "${tag}")" "${tag}"
	done | sort -V -k1,1 | tail -1 | cut -f2)"
	[[ -n "${highest}" ]] || return 1
	jq -c --arg tag "${highest}" '.[] | select(.tag_name == $tag)' <<< "${releases}"
}

github::latest_tag() {
	github::release "$@" | jq -er '.tag_name'
}

github::latest_version() {
	local tag
	tag="$(github::latest_tag "$@")" || return 1
	core::version_from_text "${tag}"
}

# Print the one asset whose name matches the pattern, as JSON
github::_pick_asset() {
	local release="$1" pattern="$2" assets count
	pattern="${pattern//\{arch\}/$(uname -m)}"
	assets="$(jq -c --arg pattern "${pattern}" '[.assets[] | select(.name | test($pattern))]' <<< "${release}")"
	count="$(jq 'length' <<< "${assets}")"
	if (( count != 1 )); then
		core::error "expected one release file matching ${pattern}, found ${count}"
		return 1
	fi
	jq -c '.[0]' <<< "${assets}"
}

# Print the sha256 a release vouches for, from GitHub's digest or a checksum file published beside the asset
github::_expected_sha256() {
	local release="$1" asset="$2" name digest checksum_url
	name="$(jq -r '.name' <<< "${asset}")"
	digest="$(jq -r '.digest // empty' <<< "${asset}")"
	if [[ "${digest}" == sha256:* ]]; then
		printf '%s\n' "${digest#sha256:}"
		return 0
	fi
	while IFS= read -r checksum_url; do
		github::_curl "${checksum_url}" | awk -v name="${name}" '
			{ file = $2; sub(/^\*/, "", file) }
			length($1) == 64 && (file == name || NF == 1) { print $1; exit }
		' | grep . && return 0
	done < <(jq -r '.assets[] | select(.name | test("sha256|checksum"; "i")) | .browser_download_url' <<< "${release}")
	return 1
}

# Download the file a source points at into a directory, check it and print its path
github::download() {
	local repository="$1" pattern="$2" flags="$3" directory="$4" release asset name expected=""

	release="$(github::release "${repository}" "${pattern}" "${flags}")" || {
		core::error "could not look up the newest release of ${repository}"
		return 1
	}
	asset="$(github::_pick_asset "${release}" "${pattern}")" || return 1
	name="$(jq -r '.name' <<< "${asset}")"
	if ! expected="$(github::_expected_sha256 "${release}" "${asset}")"; then
		if ! github::_has_flag "${flags}" no-checksum; then
			core::error "${repository} publishes no sha256 for ${name}"
			return 1
		fi
		core::warn "${repository} publishes no checksum, trusting the HTTPS download from GitHub"
	fi

	core::info "downloading ${name} from ${repository}"
	curl --fail --silent --show-error --location --max-time "${GITHUB_DOWNLOAD_TIMEOUT_SECONDS}" \
		--output "${directory}/${name}" "$(jq -r '.browser_download_url' <<< "${asset}")" || return 1
	if [[ -n "${expected}" && "$(sha256sum "${directory}/${name}" | awk '{ print $1 }')" != "${expected}" ]]; then
		core::error "checksum mismatch for ${name}"
		return 1
	fi
	printf '%s\n' "${directory}/${name}"
}

# Unpack the archive a source points at into a fresh directory, and print that directory for the caller to remove
github::unpack() {
	local download_directory unpack_directory archive status=0
	download_directory="$(mktemp -d)" || return 1
	unpack_directory="$(mktemp -d)" || return 1
	archive="$(github::download "$@" "${download_directory}")" || status=1
	(( status )) || tar -xf "${archive}" -C "${unpack_directory}" || status=1
	rm -rf "${download_directory}"
	if (( status )); then
		rm -rf "${unpack_directory}"
		return 1
	fi
	printf '%s\n' "${unpack_directory}"
}

# Releases whose files carry no version number are tracked by the tag they were installed from
github::_record_tag() {
	local repository="$1" pattern="$2" flags="$3"
	mkdir -p "${GITHUB_STATE_DIR}" \
		&& github::latest_tag "${repository}" "${pattern}" "${flags}" > "${GITHUB_STATE_DIR}/${repository//\//_}"
}

# True when what was installed from a source is its newest release, 2 when that cannot be looked up
github::_recorded_is_newest() {
	local repository="$1" pattern="$2" flags="$3" latest recorded
	latest="$(github::latest_tag "${repository}" "${pattern}" "${flags}")" || return "${CORE_EXIT_UNKNOWN}"
	recorded="$(cat "${GITHUB_STATE_DIR}/${repository//\//_}" 2>/dev/null)"
	[[ -n "${recorded}" ]] || return 1
	[[ "${recorded}" == "${latest}" ]] && return 0
	! core::version_is_older "$(core::version_from_text "${recorded}")" "$(core::version_from_text "${latest}")"
}

github::_describe() {
	printf 'Install %s from the newest github.com/%s release\n' "${1/#${HOME}/\~}" "$2"
}


# ============================================================================
# Components

# Install or update an rpm package from its newest GitHub release through zypper, which pulls in its dependencies
# Such rpms are usually unsigned, so the checked sha256 is what vouches for them
want::github_rpm() {
	local repository="$1" package="$2" pattern="$3" source_flags remaining_options
	github::_split_options "${@:4}"
	task::requirement "$(github::_describe "${package}" "${repository}")" "sudo network" \
		github::_rpm_current github::_install_rpm "${repository}" "${pattern}" "${source_flags}" "${package}"
}

github::_rpm_current() {
	local repository="$1" pattern="$2" flags="$3" package="$4" latest
	core::package_installed "${package}" || return 1
	latest="$(github::latest_version "${repository}" "${pattern}" "${flags}")" || return "${CORE_EXIT_UNKNOWN}"
	! core::version_is_older "$(rpm -q --qf '%{VERSION}\n' "${package}")" "${latest}"
}

github::_install_rpm() {
	local directory rpm_file status=0
	directory="$(mktemp -d)" || return 1
	rpm_file="$(github::download "$1" "$2" "$3" "${directory}")" || status=1
	(( status )) || core::zypper install --allow-unsigned-rpm "${rpm_file}" || status=1
	rm -rf "${directory}"
	return "${status}"
}

# Install one release file, such as an AppImage or a single program, at a path and keep it on the newest release
want::github_file() {
	local repository="$1" pattern="$2" destination="$3" source_flags remaining_options
	github::_split_options "${@:4}"
	task::requirement "$(github::_describe "${destination}" "${repository}")" network \
		github::_file_current github::_install_file "${repository}" "${pattern}" "${source_flags}" "${destination}"
}

github::_file_current() {
	[[ -f "$4" ]] || return 1
	github::_recorded_is_newest "$1" "$2" "$3"
}

github::_install_file() {
	local repository="$1" pattern="$2" flags="$3" destination="$4" directory file status=0
	directory="$(mktemp -d)" || return 1
	file="$(github::download "${repository}" "${pattern}" "${flags}" "${directory}")" || status=1
	(( status )) || install -D -m 0755 "${file}" "${destination}" || status=1
	(( status )) || github::_record_tag "${repository}" "${pattern}" "${flags}" || status=1
	rm -rf "${directory}"
	return "${status}"
}

# Install chosen programs out of a release archive into a folder, such as ~/.local/bin
want::github_programs() {
	local repository="$1" pattern="$2" directory="$3" source_flags remaining_options
	github::_split_options "${@:4}"
	task::requirement "Install ${remaining_options[*]} from the newest github.com/${repository} release" network \
		github::_programs_current github::_install_programs \
		"${repository}" "${pattern}" "${source_flags}" "${directory}" "${remaining_options[@]}"
}

github::_programs_current() {
	local repository="$1" pattern="$2" flags="$3" directory="$4" program
	for program in "${@:5}"; do
		[[ -x "${directory}/${program}" ]] || return 1
	done
	github::_recorded_is_newest "${repository}" "${pattern}" "${flags}"
}

github::_install_programs() {
	local repository="$1" pattern="$2" flags="$3" directory="$4" unpacked program found status=0
	unpacked="$(github::unpack "${repository}" "${pattern}" "${flags}")" || return 1
	for program in "${@:5}"; do
		found="$(find "${unpacked}" -type f -name "${program}" | head -1)"
		if [[ -z "${found}" ]]; then
			core::error "${program} is not in the ${repository} release"
			status=1
			continue
		fi
		install -D -m 0755 "${found}" "${directory}/${program}" || status=1
	done
	rm -rf "${unpacked}"
	(( status )) || github::_record_tag "${repository}" "${pattern}" "${flags}"
}

# Unpack the newest release archive into a folder, replacing what was there, and keep it on the newest release
# --strip N drops leading folders, --root makes a root owned folder outside home and --yours gives such a folder to you
#
# --self-updating is for apps that update themselves, which are then only installed when missing
want::github_archive() {
	local repository="$1" pattern="$2" destination="$3" source_flags remaining_options strip=0 privilege=""
	local self_updating=0 yours=0
	github::_split_options "${@:4}"
	set -- "${remaining_options[@]}"
	while (( $# )); do
		case "$1" in
			--strip) strip="$2"; shift 2 ;;
			--root) privilege=sudo; shift ;;
			--self-updating) self_updating=1; shift ;;
			--yours) yours=1; shift ;;
			*) core::error "want::github_archive does not know $1"; return 1 ;;
		esac
	done
	task::requirement "$(github::_describe "${destination}" "${repository}")" "${privilege:+${privilege} }network" \
		github::_archive_current github::_install_archive \
		"${repository}" "${pattern}" "${source_flags}" "${destination}" "${strip}" "${privilege}" \
		"${self_updating}" "${yours}"
}

github::_archive_current() {
	local destination="$4" self_updating="$7"
	[[ -n "$(ls -A "${destination}" 2>/dev/null)" ]] || return 1
	(( self_updating )) && return 0
	github::_recorded_is_newest "$1" "$2" "$3"
}

github::_install_archive() {
	local repository="$1" pattern="$2" flags="$3" destination="$4" strip="$5" privilege="$6" yours="$8" unpacked source
	local run_as=() owner="$(id -u):$(id -g)" status=0
	[[ -n "${privilege}" ]] && run_as=(core::as_root)
	(( yours )) || [[ -z "${privilege}" ]] || owner=root:root
	unpacked="$(github::unpack "${repository}" "${pattern}" "${flags}")" || return 1
	source="${unpacked}"
	while (( strip-- > 0 )); do
		source="$(find "${source}" -mindepth 1 -maxdepth 1 -type d | head -1)"
	done
	"${run_as[@]}" rm -rf "${destination}" && "${run_as[@]}" mkdir -p "${destination}" \
		&& "${run_as[@]}" cp -a "${source}/." "${destination}/" \
		&& "${run_as[@]}" chown -R "${owner}" "${destination}" && "${run_as[@]}" chmod 0755 "${destination}" \
		&& github::_record_tag "${repository}" "${pattern}" "${flags}" || status=1
	rm -rf "${unpacked}"
	return "${status}"
}


# ============================================================================
# Desktop apps

# Install a desktop app from a release archive that holds its program next to a share/ folder
# The archive is unpacked into ~/.local/share/tumblegecko/apps/<name>, and the program, launchers, icons and notes are
# linked into ~/.local, so the app shows up in the menu and a newer release replaces it in place
want::github_app() {
	local repository="$1" pattern="$2" name="$3" destination
	destination="${XDG_DATA_HOME:-${HOME}/.local/share}/tumblegecko/apps/${name}"
	want::github_archive "${repository}" "${pattern}" "${destination}" --strip 1 "${@:4}"
	task::requirement "Add ${name} to the menu" "" github::_app_linked github::_link_app "${name}" "${destination}"
}

# The launchers name the program only, so each is written out with its full path and works before the PATH is set
github::_write_launcher() {
	local name="$1" file="$2"
	sed "s#^Exec=${name}\( \|$\)#Exec=${HOME}/.local/bin/${name}\1#; s#^Exec=env \(.*\) ${name}\( \|$\)#Exec=env \1 ${HOME}/.local/bin/${name}\2#" \
		"${file}"
}

# A launcher that differs from the release's counts as missing, so a newer release replaces it
github::_app_linked() {
	local name="$1" launcher file
	[[ -L "${HOME}/.local/bin/${name}" ]] || return 1
	for launcher in "$2/share/applications/"*.desktop; do
		cmp -s "${XDG_DATA_HOME:-${HOME}/.local/share}/applications/${launcher##*/}" \
			<(github::_write_launcher "${name}" "${launcher}") || return 1
	done
	# A release can add an icon, such as a tray icon, which counts as missing until it is linked
	while IFS= read -r file; do
		[[ -e "${XDG_DATA_HOME:-${HOME}/.local/share}/${file#"$2"/share/}" ]] || return 1
	done < <(find "$2/share/icons" "$2/share/metainfo" -type f 2>/dev/null)
}

github::_link_app() {
	local name="$1" destination="$2" data="${XDG_DATA_HOME:-${HOME}/.local/share}" file target
	mkdir -p "${HOME}/.local/bin" "${data}/applications" || return 1
	ln -sfn "${destination}/${name}" "${HOME}/.local/bin/${name}" || return 1
	for file in "${destination}/share/applications/"*.desktop; do
		github::_write_launcher "${name}" "${file}" > "${data}/applications/${file##*/}" || return 1
	done
	while IFS= read -r file; do
		target="${data}/${file#"${destination}"/share/}"
		mkdir -p "${target%/*}" && ln -sfn "${file}" "${target}" || return 1
	done < <(find "${destination}/share/icons" "${destination}/share/metainfo" -type f 2>/dev/null)
	update-desktop-database "${data}/applications" >/dev/null 2>&1 || true
	gtk-update-icon-cache --quiet --ignore-theme-index "${data}/icons/hicolor" >/dev/null 2>&1 || true
}


# ============================================================================
# Python programs

# Install a program from the Python wheel in the newest release with pipx, which keeps it in its own environment
want::github_pipx() {
	local repository="$1" pattern="$2" program="$3" source_flags remaining_options
	github::_split_options "${@:4}"
	task::requirement "Install ${program} with pipx from the newest github.com/${repository} release" network \
		github::_pipx_current github::_install_pipx "${repository}" "${pattern}" "${source_flags}" "${program}"
}

github::_pipx_current() {
	command -v "$4" >/dev/null 2>&1 || return 1
	github::_recorded_is_newest "$1" "$2" "$3"
}

# The wheel keeps its own file name while it installs, since pip reads the version from it
github::_install_pipx() {
	local repository="$1" pattern="$2" flags="$3" directory wheel status=0
	directory="$(mktemp -d)" || return 1
	wheel="$(github::download "${repository}" "${pattern}" "${flags}" "${directory}")" || status=1
	(( status )) || pipx install --force "${wheel}" || status=1
	(( status )) || github::_record_tag "${repository}" "${pattern}" "${flags}" || status=1
	rm -rf "${directory}"
	return "${status}"
}
