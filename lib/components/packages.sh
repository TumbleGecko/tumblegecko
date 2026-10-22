# lib/components/packages.sh, rpm packages and zypper repositories

# Install packages through zypper, passing leading options such as --no-recommends along to it
want::packages() {
	local options=()
	while [[ "${1:-}" == --* ]]; do
		options+=("$1")
		shift
	done
	task::requirement "Install $(packages::_list "$@")" "sudo network" \
		packages::_installed packages::_install "${#options[@]}" "${options[@]}" "$@"
}

packages::_list() {
	local joined
	joined="$(printf '%s, ' "$@")"
	printf '%s\n' "${joined%, }"
}

packages::_installed() {
	local option_count="$1" package
	shift $((option_count + 1))
	for package in "$@"; do
		core::package_installed "${package}" || return 1
	done
}

packages::_install() {
	local option_count="$1"
	shift
	local options=("${@:1:option_count}")
	shift "${option_count}"
	core::zypper install --auto-agree-with-licenses "${options[@]}" "$@"
}

# Remove packages by name, leaving their dependencies alone
want::no_packages() {
	task::requirement "Remove $(packages::_list "$@")" sudo packages::_all_absent packages::_remove "$@"
}

packages::_all_absent() {
	local package
	for package in "$@"; do
		core::package_installed "${package}" && return 1
	done
	return 0
}

packages::_remove() {
	local package present=()
	for package in "$@"; do
		core::package_installed "${package}" && present+=("${package}")
	done
	core::zypper remove "${present[@]}"
}

# Lock packages so no update can install them again
want::package_locks() {
	task::requirement "Keep $(packages::_list "$@") from being installed again" sudo \
		packages::_locked packages::_lock "$@"
}

packages::_locked() {
	local locks package
	locks="$(zypper --no-refresh --xmlout locks 2>/dev/null | grep -o '<name>[^<]*</name>' | sed 's/<[^>]*>//g')"
	for package in "$@"; do
		grep -qx -- "${package}" <<< "${locks}" || return 1
	done
}

packages::_lock() {
	core::zypper addlock "$@"
}

# Install the highest numbered package of a series, plus companions named with the same number
# {N} in a companion stands for that number, so nvidia-gl-G{N}-32bit follows the driver generation
want::newest_numbered_package() {
	local prefix="$1" suffix="$2"
	shift 2
	local text="Install the newest ${prefix}<N>${suffix}"
	(( $# )) && text+=" with ${*//\{N\}/<N>}"
	task::requirement "${text}" "sudo network" \
		packages::_numbered_installed packages::_numbered_install "${prefix}" "${suffix}" "$@"
}

packages::_numbered_names() {
	local prefix="$1" suffix="$2" newest number companion
	shift 2
	newest="$(core::newest_numbered_package "${prefix}" "${suffix}")" || return 1
	[[ "${newest}" =~ ^${prefix}([0-9]+)${suffix}$ ]]
	number="${BASH_REMATCH[1]}"
	printf '%s\n' "${newest}"
	for companion in "$@"; do
		printf '%s\n' "${companion//\{N\}/${number}}"
	done
}

packages::_numbered_installed() {
	local names name
	names="$(packages::_numbered_names "$@")" || return 1
	while IFS= read -r name; do
		core::package_installed "${name}" || return 1
	done <<< "${names}"
}

packages::_numbered_install() {
	local names
	core::zypper refresh || return 1
	names="$(packages::_numbered_names "$@")" || {
		core::error "no ${1}<N>${2} package in the enabled repositories"
		return 1
	}
	mapfile -t names <<< "${names}"
	core::zypper install --auto-agree-with-licenses "${names[@]}"
}

# Disable every repository whose alias matches an extended regex
want::repositories_disabled() {
	local pattern="$1" text="$2"
	task::requirement "${text}" sudo packages::_none_enabled packages::_disable "${pattern}"
}

packages::_enabled_aliases() {
	zypper --no-refresh --xmlout repos 2>/dev/null \
		| grep -o '<repo [^>]*>' | grep 'enabled="1"' \
		| grep -o ' alias="[^"]*"' | sed 's/ alias="\(.*\)"/\1/'
}

packages::_none_enabled() {
	! packages::_enabled_aliases | grep -Eq -- "$1"
}

packages::_disable() {
	local alias
	while IFS= read -r alias; do
		core::zypper modifyrepo --disable "${alias}" || return 1
	done < <(packages::_enabled_aliases | grep -E -- "$1")
	core::zypper refresh
}

# Add and enable a zypper repository by alias and address
# --priority sets its priority and --key names the URL of a signing key to import first
want::repository() {
	local alias="$1" address="$2" priority="" key=""
	shift 2
	while (( $# )); do
		case "$1" in
			--priority) priority="$2"; shift 2 ;;
			--key) key="$2"; shift 2 ;;
			*) core::error "want::repository does not know $1"; return 1 ;;
		esac
	done
	task::requirement "Add the ${alias} repository" "sudo network" \
		packages::_repository_enabled packages::_add_repository "${alias}" "${address}" "${priority}" "${key}"
}

packages::_repository_enabled() {
	packages::_enabled_aliases | grep -qx -- "$1"
}

packages::_add_repository() {
	local alias="$1" address="$2" priority="$3" key="$4"
	if [[ -n "${key}" ]]; then
		core::as_root rpm --import "${key}" || return 1
	fi
	if zypper --no-refresh --xmlout repos 2>/dev/null | grep -q " alias=\"${alias}\""; then
		core::zypper modifyrepo --enable "${alias}" || return 1
	else
		core::zypper addrepo --check --refresh ${priority:+--priority "${priority}"} "${address}" "${alias}" || return 1
	fi
	core::zypper --gpg-auto-import-keys refresh "${alias}"
}

# Print the vendor of an installed package
packages::vendor() {
	rpm -q --qf '%{VENDOR}\n' "$1" 2>/dev/null
}
