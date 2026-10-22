#!/usr/bin/env bash
# name:     Steam
# summary:  Installs Steam, starts it quietly in the tray, and lets Remote Play, Steam Link and SteamVR streaming reach this PC.
# default:  on
#
# steam from repo-non-oss is openSUSE's wrapper around Valve's installer
# Without steam-devices and the two hidapi libraries the Steam Controller 2.0 firmware update fails silently
#
# -silent starts the client in the tray
# GPUAccelWebViewsV3 is "GPU accelerated rendering in web views" in Steam's settings, kept in ~/.steam/registry.vdf
#
# Steam rewrites that file while running, so it is only edited while Steam is closed
#
# Two separate failures, and fixing the first shows the second, both found 2026-08-07 with a Quest 3
# A stock install allows almost nothing inbound, so Steam Link says "we're not on the same local network"
#
# firewalld's own steam-streaming and steam-lan-transfer services fix that, so a Valve port change stays theirs
# With discovery working SteamVR hangs on "Awaiting Wireless Connection", because its stream uses UDP 10400 and 10401
#
# firewalld ships no definition for those yet, see https://github.com/firewalld/firewalld/issues/1514

REGISTRY="${HOME}/.steam/registry.vdf"

gpu_web_views_on() {
	grep -Eq '"GPUAccelWebViewsV3"[[:space:]]+"1"' "${REGISTRY}" 2>/dev/null
}

# Set the key inside Registry, HKCU, Software, Valve, Steam, creating the file when Steam has never run
turn_on_gpu_web_views() {
	local key=GPUAccelWebViewsV3 value=1 edited
	if pgrep -u "$(id -u)" -x steam >/dev/null; then
		core::error "Steam is running and would overwrite this when it quits, close Steam and run this again"
		return 1
	fi
	mkdir -p "$(dirname "${REGISTRY}")" || return 1
	if [[ ! -f "${REGISTRY}" ]]; then
		cat > "${REGISTRY}" <<VDF
"Registry"
{
	"HKCU"
	{
		"Software"
		{
			"Valve"
			{
				"Steam"
				{
					"${key}"		"${value}"
				}
			}
		}
	}
}
VDF
		return
	fi
	if grep -qF "\"${key}\"" "${REGISTRY}"; then
		sed -i -E "s|(\"${key}\"[[:space:]]+)\"[01]\"|\\1\"${value}\"|" "${REGISTRY}"
		return
	fi
	edited="$(awk -v key="${key}" -v val="${value}" '
		function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
		{
			line = $0
			t = trim(line)
			if (t ~ /^"[^"]+"$/) {
				last_section = t
				gsub(/"/, "", last_section)
			}
			if (t == "{") {
				depth++
				path[depth] = last_section
			}
			if (t == "}") {
				# Closing HKCU, Software, Valve, Steam adds the key just before the brace
				if (depth == 5 \
					&& path[2] == "HKCU" \
					&& path[3] == "Software" \
					&& path[4] == "Valve" \
					&& path[5] == "Steam") {
					indent = ""
					for (i = 1; i <= depth; i++) indent = indent "\t"
					printf("%s\"%s\"\t\t\"%s\"\n", indent, key, val)
				}
				depth--
			}
			print line
		}
' "${REGISTRY}")" || return 1
	printf '%s\n' "${edited}" > "${REGISTRY}"
}

task() {
	want::packages --no-recommends steam steam-devices libhidapi-hidraw0 libhidapi-libusb0
	want::autostart steam.desktop -silent
	want::step "Turn on GPU accelerated web views in Steam" "" gpu_web_views_on turn_on_gpu_web_views
	want::packages firewalld
	want::system_unit firewalld.service --now
	want::firewall_service steam-streaming
	want::firewall_service steam-lan-transfer
	want::firewall_port 10400/udp
	want::firewall_port 10401/udp
}
