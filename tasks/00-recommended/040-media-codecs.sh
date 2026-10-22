#!/usr/bin/env bash
# name:     Media codecs
# summary:  Plays every common video and audio format by taking the codec libraries from Packman Essentials.
# default:  on
#
# Packman is the codec source openSUSE documents for Tumbleweed, so it is an accepted third party repository
# Source https://en.opensuse.org/SDB:Installing_codecs_from_Packman_repositories, option 1, Packman Essentials
#
# The ffmpeg libraries do the decoding and the GStreamer plugins wrap them
# So the check is that every installed libav*, libsw* and libx264 or libx265 library comes from Packman
#
# Names are listed stem by stem because libav* alone would also match libavif and libavtp
# zypper dist-upgrade --from repo-oss --allow-vendor-change and removing packman-essentials undoes it

PACKMAN_ALIAS=packman-essentials
CODEC_PACKAGES=(ffmpeg gstreamer-plugins-good gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-plugins-libav
	libavcodec vlc-codecs)
PACKMAN_URL=https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/
CODEC_LIBRARIES='libavutil|libavcodec|libavformat|libavfilter|libavdevice|libswscale|libswresample'
CODEC_LIBRARY_PATTERN="^(${CODEC_LIBRARIES})[0-9]+\$|^libx26[45]-[0-9]+\$"

codecs_from_packman() {
	local package count=0
	while IFS= read -r package; do
		count=$((count + 1))
		[[ "$(packages::vendor "${package}")" == http://packman* ]] || return 1
	done < <(rpm -qa --qf '%{NAME}\n' | grep -E "${CODEC_LIBRARY_PATTERN}")
	(( count > 0 ))
}

install_codecs() {
	core::zypper install --auto-agree-with-licenses --allow-vendor-change --from "${PACKMAN_ALIAS}" \
		"${CODEC_PACKAGES[@]}"
}

task() {
	want::repository "${PACKMAN_ALIAS}" "${PACKMAN_URL}" \
		--priority 90
	want::step "Take the codec libraries from Packman" "sudo network" codecs_from_packman install_codecs
}
