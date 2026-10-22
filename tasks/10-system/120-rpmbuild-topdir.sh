#!/usr/bin/env bash
# name:     Hidden rpmbuild folder
# summary:  Building rpm packages works in a hidden ~/.rpmbuild instead of leaving an rpmbuild folder in your home.
# default:  on
#
# rpm reads %_topdir from ~/.rpmmacros, and rpm --eval shows what it resolves to
# An old ~/rpmbuild is only removed when it holds no files

TOP_DIRECTORY="${HOME}/.rpmbuild"

rpm_macros() {
	printf '%s\n' '%_topdir %{getenv:HOME}/.rpmbuild'
}

old_tree_gone() {
	[[ ! -d "${HOME}/rpmbuild" ]] || [[ -n "$(find "${HOME}/rpmbuild" -type f -print -quit)" ]]
}

remove_empty_old_tree() {
	rm -rf "${HOME}/rpmbuild"
}

top_directory_used() {
	[[ "$(rpm --eval '%_topdir')" == "${TOP_DIRECTORY}" ]]
}

drop_other_topdirs() {
	sed -i '/^[[:space:]]*%_topdir[[:space:]]/d' "${HOME}/.rpmmacros"
}

task() {
	local folder
	want::block "${HOME}/.rpmmacros" rpmbuild-topdir rpm_macros
	want::step "rpm builds in ~/.rpmbuild" "" top_directory_used drop_other_topdirs
	for folder in BUILD RPMS SOURCES SPECS SRPMS; do
		want::directory "${TOP_DIRECTORY}/${folder}"
	done
	want::step "Remove an empty ~/rpmbuild" "" old_tree_gone remove_empty_old_tree
}
