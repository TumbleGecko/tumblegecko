# lib/components/git.sh, git's own settings, and sources that live in a git branch

# Set a global git setting, and with --unless-set any value you chose yourself is kept
want::git_config() {
	local key="$1" value="$2" mode="${3:-}"
	task::requirement "Set git ${key} to ${value}${mode:+ unless you chose one}" "" \
		git_config::_matches git_config::_write "${key}" "${value}" "${mode}"
}

git_config::_matches() {
	local key="$1" value="$2" mode="$3" current
	current="$(git config --global --get "${key}")"
	[[ "${mode}" == --unless-set && -n "${current}" ]] && return 0
	[[ "${current}" == "${value}" ]]
}

git_config::_write() {
	git config --global "$1" "$2"
}

# Keep a folder on the newest commit of a branch, for projects that publish no releases at all
# git ls-remote works with any host and needs no API
#
# The commit is recorded inside the folder, so a fresh copy of a parent folder fetches it again
want::git_branch() {
	local address="$1" branch="$2" destination="$3"
	task::requirement "Install ${destination/#${HOME}/\~} from the newest ${branch} of ${address#https://}" network \
		git_source::_current git_source::_install "${address}" "${branch}" "${destination}"
}

GIT_COMMIT_MARKER=.tumblegecko-commit

# Login helpers are off, so a private repository fails at once instead of asking for a password
git_source::newest_commit() {
	GIT_TERMINAL_PROMPT=0 git -c credential.helper= ls-remote "$1" "refs/heads/$2" 2>/dev/null | cut -f1 | grep .
}

git_source::_current() {
	local address="$1" branch="$2" destination="$3" newest
	[[ -f "${destination}/${GIT_COMMIT_MARKER}" ]] || return 1
	newest="$(git_source::newest_commit "${address}" "${branch}")" || return "${CORE_EXIT_UNKNOWN}"
	[[ "$(cat "${destination}/${GIT_COMMIT_MARKER}")" == "${newest}" ]]
}

git_source::_install() {
	local address="$1" branch="$2" destination="$3" checkout status=0
	checkout="$(mktemp -d)" || return 1
	GIT_TERMINAL_PROMPT=0 git -c credential.helper= clone --quiet --depth 1 --branch "${branch}" "${address}" "${checkout}/source" || status=1
	if (( status == 0 )); then
		git -C "${checkout}/source" rev-parse HEAD > "${checkout}/source/${GIT_COMMIT_MARKER}" \
			&& rm -rf "${checkout}/source/.git" "${destination}" && mkdir -p "$(dirname "${destination}")" \
			&& mv "${checkout}/source" "${destination}" || status=1
	fi
	rm -rf "${checkout}"
	return "${status}"
}
