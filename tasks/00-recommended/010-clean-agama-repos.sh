#!/usr/bin/env bash
# name:     Clean up Agama installer repos
# summary:  Turns off the duplicate repositories the Agama installer leaves behind.
# default:  on
#
# Agama adds agama-0, agama-1 and so on beside the normal repositories, so every refresh fetches them twice
# Source https://forums.opensuse.org/t/agama-experience-and-tw-repos/192816
#
# Also reported at https://bugzilla.opensuse.org/show_bug.cgi?id=1235693
#
# They are disabled rather than removed, so zypper modifyrepo --enable undoes it

task() {
	want::repositories_disabled '^agama-[0-9]+$' "Turn off the duplicate agama-* repositories"
}
