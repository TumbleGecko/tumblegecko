#!/usr/bin/env bash
# name:     BlitzMax NG
# summary:  Installs the newest BlitzMax NG with its bls language server, ready for VS Code, and adds a BlitzMax project to Dolphin's Create New menu.
# default:  off
#
# Releases are weekly pre-releases at https://github.com/bmx-ng/bmx-ng/releases, one per platform
# The bcc2 and bmk2 edition is the 1.x series and the older bcc edition 0.165, so the highest Linux version is bcc2
#
# There is one install in ~/.local/share/blitzmax-ng, replaced by each new release, with the release tag inside it
# The VS Code extension has no default location, it reads blitzmax.base.path and wants bin/bmk there
#
# blitzmax.org's package list is stale, today the packages are webkitgtk3-devel, alsa-devel and freetype2-devel
# GCC 14 made implicit declarations an error, which breaks freejoy.linux.c in every build's default imports
#
# Source https://gcc.gnu.org/gcc-14/changes.html
# The two missing includes are added, which does nothing once upstream adds them
#
# bmk is wrapped so BMXPATH points at the install, which BlitzMax's own BlitzMaxPath() reads
# bls is wrapped the same way, so editors other than VS Code find the language server on the PATH
# Print adds a \r even on Linux, so the test strips it before comparing

BLITZMAX="${HOME}/.local/share/blitzmax-ng"
BLITZMAX_RELEASE='^BlitzMax_linux_x64_.*\.tar\.xz$'
RELEASE_MARKER="${BLITZMAX}/.tumblegecko-release"
VERIFIED_MARKER="${BLITZMAX}/.tumblegecko-verified"

newest_release() {
	github::latest_tag bmx-ng/bmx-ng "${BLITZMAX_RELEASE}" prereleases
}

newest_release_installed() {
	local tag
	tag="$(newest_release)" || return "${CORE_EXIT_UNKNOWN}"
	[[ -x "${BLITZMAX}/bin/bmk" && -x "${BLITZMAX}/bin/bls" && "$(cat "${RELEASE_MARKER}" 2>/dev/null)" == "${tag}" ]]
}

install_newest_release() {
	local tag unpacked status=0
	tag="$(newest_release)" || return 1
	unpacked="$(github::unpack bmx-ng/bmx-ng "${BLITZMAX_RELEASE}" prereleases)" || return 1
	rm -rf "${BLITZMAX}" && mkdir -p "$(dirname "${BLITZMAX}")" && mv "${unpacked}/BlitzMax" "${BLITZMAX}" \
		&& printf '%s\n' "${tag}" > "${RELEASE_MARKER}" || status=1
	rm -rf "${unpacked}"
	return "${status}"
}

freejoy_patched() {
	grep -q '#include <stdlib.h>' "${BLITZMAX}/mod/pub.mod/freejoy.mod/freejoy.linux.c" 2>/dev/null
}

patch_freejoy() {
	sed -i '/#include "freejoy.h"/a\
#include <stdlib.h>\
#include <string.h>' "${BLITZMAX}/mod/pub.mod/freejoy.mod/freejoy.linux.c"
}

# Prints a wrapper that runs one of the install's programs with BMXPATH pointing at the install
tool_wrapper() {
	cat <<SCRIPT
#!/usr/bin/env bash
# Run ${1} with BMXPATH pointing at the BlitzMax NG install TumbleGecko keeps
export BMXPATH="${BLITZMAX}"
exec "${BLITZMAX}/bin/${1}" "\$@"
SCRIPT
}

bmk_wrapper() {
	tool_wrapper bmk
}

bls_wrapper() {
	tool_wrapper bls
}

hello_world_proven() {
	[[ "$(cat "${VERIFIED_MARKER}" 2>/dev/null)" == "$(cat "${RELEASE_MARKER}" 2>/dev/null)" ]]
}

# Build and run Hello World once per release, which also compiles the default modules
prove_hello_world() {
	local directory output status=0
	directory="$(mktemp -d)" || return 1
	printf 'Print "Hello, BlitzMax NG!"\n' > "${directory}/hello.bmx"
	if "${HOME}/.local/bin/bmk" makeapp -r -o "${directory}/hello" "${directory}/hello.bmx"; then
		output="$("${directory}/hello")"
		[[ "${output%$'\r'}" == "Hello, BlitzMax NG!" ]] || { core::error "Hello World printed '${output}'"; status=1; }
	else
		status=1
	fi
	rm -rf "${directory}"
	(( status )) || cp "${RELEASE_MARKER}" "${VERIFIED_MARKER}"
}

SOURCES="${HOME}/Templates/.source"

blitzmax_main() {
	cat <<'BMX'
SuperStrict

Framework BRL.StandardIO

Print "Hello, World!"
BMX
}

blitzmax_gitignore() {
	printf '%s\n' .bmx/ '*.debug' '*.o' '*.a'
}

task() {
	want::packages --no-recommends gcc-c++ libXxf86vm-devel webkitgtk3-devel alsa-devel freetype2-devel libpulse-devel \
		glu-devel libXss-devel systemd-devel
	want::step "Install the newest BlitzMax NG" network newest_release_installed install_newest_release
	want::step "Fix freejoy.linux.c for GCC 14 and newer" "" freejoy_patched patch_freejoy
	want::file "${HOME}/.local/bin/bmk" bmk_wrapper --mode 0755
	want::file "${HOME}/.local/bin/bls" bls_wrapper --mode 0755
	want::json_value "${HOME}/.config/Code/User/settings.json" '."blitzmax.base.path"' "\"${BLITZMAX}\""
	want::step "Build and run a test program" "" hello_world_proven prove_hello_world
	want::file "${SOURCES}/blitzmax-project/main.bmx" blitzmax_main
	want::file "${SOURCES}/blitzmax-project/.gitignore" blitzmax_gitignore
	want::dolphin_template "BlitzMax Project" blitzmax-project "Empty BlitzMax NG program"
}
