#!/usr/bin/env bash
# name:     Proton-GE
# summary:  Installs the newest Proton-GE as Wine with .NET, Visual C++, fonts and DXVK, and puts the shortcuts Windows programs install on the desktop.
# default:  on
#
# Proton-GE replaces any distro Wine, so there is one Wine and it is GloriousEggroll's newest release
# Each release gets its own folder in /opt/proton-ge, "current" points at the active one and the shims follow it
#
# The prefix is ~/.wine with drive_c moved to ~/Windows, and scripts use ~/.wine/drive_c because the target can move
# Proton-GE has no wineboot of its own, so "wine wineboot" starts the prefix with mscoree off to skip the Mono dialog
#
# zypper's winetricks pulls 36 wine packages, so it comes from upstream
# Its verbs are checked one by one against winetricks.log, and win11 keeps the Battle.net agent from crashing
#
# Proton normally copies its DXVK and VKD3D-Proton DLLs into a prefix on first start, through a wrapper not used here
# Without them the fakedll dxgi chain fails on Plasma Wayland, so they are copied in with native,builtin overrides
#
# DXVA2 backend va and locationapi off come from Lutris' Battle.net installer
# Source https://lutris.net/games/install/37360/view
#
# Double-clicked Windows programs go through the gecko-run task, which also reruns installers this WoW64 build crashes
#
# Battle.net's black login window is an NVIDIA driver regression, so nothing here works around it
#
# ~/Windows, the Wine C drive, gets a Windows folder icon so it stands out in Dolphin
#
# Proton-GE puts installer shortcuts in ~/.wine/drive_c/proton_shortcuts, where nobody looks
# wine-shortcut-sync mirrors them to ~/Desktop with Exec on the wine shim and Icon on the extracted icon, and tags them
#
# A tagged desktop copy whose source is gone is removed, and a hand made launcher with the same name is never touched
# One user service syncs on every change in proton_shortcuts, the other removes the source when you delete its copy
#
# systemd .path units only fire on writes and creations and cannot see deletions, so both run inotifywait
# Paths go through ~/.wine/drive_c, wine's own prefix path, never the ~/Windows link target

PROTON_ROOT=/opt/proton-ge
CURRENT="${PROTON_ROOT}/current"
PROTON_RELEASE='^GE-Proton[0-9-]+-{arch}\.tar\.gz$'
PREFIX="${HOME}/.wine"
DRIVE_C="${HOME}/Windows"
WINETRICKS_VERBS=(dotnet48 vcrun2022 corefonts tahoma arial d3dcompiler_47 gdiplus riched20 win11)
# gecko-run opens programs, installers and shortcuts, and Wine keeps the package types it leaves alone
WINDOWS_TYPES=(application/x-msdos-program application/x-wine-extension-msp application/msix application/msixbundle)
OVERRIDDEN_DLLS=(d3d8 d3d9 d3d10core d3d11 d3d12 d3d12core dxgi)

# Print each bundled DLL as "source destination", 64-bit ones into system32 and 32-bit ones into syswow64
bundled_dlls() {
	local folder dll windows="${PREFIX}/drive_c/windows"
	for folder in wine/dxvk:d3d8.dll,d3d9.dll,d3d10core.dll,d3d11.dll,dxgi.dll \
		wine/vkd3d-proton:d3d12.dll,d3d12core.dll vkd3d:libvkd3d-1.dll,libvkd3d-shader-1.dll; do
		for dll in ${folder#*:}; do
			dll="${dll//,/ }"
			for dll in ${dll}; do
				printf '%s %s\n' "${CURRENT}/files/lib/${folder%%:*}/x86_64-windows/${dll}" "${windows}/system32/${dll}"
				printf '%s %s\n' "${CURRENT}/files/lib/${folder%%:*}/i386-windows/${dll}" "${windows}/syswow64/${dll}"
			done
		done
	done
}

prefix_wine() {
	WINEPREFIX="${PREFIX}" "${CURRENT}/files/bin/wine" "$@"
}

no_distro_wine() {
	! rpm -qa --qf '%{NAME}\n' | grep -qE '^wine($|-)'
}

remove_distro_wine() {
	mapfile -t packages < <(rpm -qa --qf '%{NAME}\n' | grep -E '^wine($|-)')
	core::zypper remove --clean-deps "${packages[@]}"
}

newest_proton_active() {
	local tag
	tag="$(github::latest_tag GloriousEggroll/proton-ge-custom "${PROTON_RELEASE}" "")" || return "${CORE_EXIT_UNKNOWN}"
	[[ "$(basename "$(readlink "${CURRENT}")")" == "${tag}" && -x "${CURRENT}/files/bin/wine" ]]
}

install_newest_proton() {
	local tag unpacked
	tag="$(github::latest_tag GloriousEggroll/proton-ge-custom "${PROTON_RELEASE}" "")" || return 1
	if [[ ! -d "${PROTON_ROOT}/${tag}" ]]; then
		unpacked="$(github::unpack GloriousEggroll/proton-ge-custom "${PROTON_RELEASE}" "")" || return 1
		# The archive holds one folder, named by the release rather than exactly by its tag
		core::as_root mkdir -p "${PROTON_ROOT}" \
			&& core::as_root mv "$(find "${unpacked}" -mindepth 1 -maxdepth 1 -type d | head -1)" \
				"${PROTON_ROOT}/${tag}"
		rm -rf "${unpacked}"
	fi
	core::as_root ln -sfn "${PROTON_ROOT}/${tag}" "${CURRENT}" || return 1
	[[ -f "${PREFIX}/system.reg" ]] || return 0
	# A new Wine updates the prefix on its next start, where dotnet48's mscoree shows ".NET could not start rundll32"
	# So the update runs here with mscoree off, and --restart keeps startup programs such as Battle.net closed
	WINEDLLOVERRIDES="mscoree=" prefix_wine wineboot --update --restart \
		&& WINEPREFIX="${PREFIX}" "${CURRENT}/files/bin/wineserver" -w
}

prefix_ready() {
	[[ -L "${PREFIX}/drive_c" && "$(readlink "${PREFIX}/drive_c")" == "${DRIVE_C}" && -f "${PREFIX}/system.reg" ]]
}

create_prefix() {
	if [[ ! -d "${PREFIX}/drive_c" && ! -L "${PREFIX}/drive_c" ]]; then
		WINEDLLOVERRIDES="mscoree=" prefix_wine wineboot --init || return 1
	fi
	if [[ -d "${PREFIX}/drive_c" && ! -L "${PREFIX}/drive_c" ]]; then
		if [[ -e "${DRIVE_C}" ]]; then
			rm -rf "${PREFIX}/drive_c"
		else
			mv "${PREFIX}/drive_c" "${DRIVE_C}" || return 1
		fi
	fi
	ln -sfn "${DRIVE_C}" "${PREFIX}/drive_c"
}

verbs_installed() {
	local verb
	for verb in "${WINETRICKS_VERBS[@]}"; do
		grep -qxF "${verb}" "${PREFIX}/winetricks.log" 2>/dev/null || return 1
	done
}

install_verbs() {
	WINEPREFIX="${PREFIX}" WINE="${CURRENT}/files/bin/wine" \
		"${HOME}/.local/bin/winetricks" --unattended "${WINETRICKS_VERBS[@]}"
}

# The copies must match the active Proton-GE, so a Proton update brings new DLLs into the prefix as well
dlls_deployed() {
	local source destination dll
	while read -r source destination; do
		cmp -s "${source}" "${destination}" || return 1
	done < <(bundled_dlls)
	for dll in "${OVERRIDDEN_DLLS[@]}"; do
		grep -qF "\"${dll}\"=\"native,builtin\"" "${PREFIX}/user.reg" || return 1
	done
}

deploy_dlls() {
	local source destination dll
	while read -r source destination; do
		install -D -m 0644 "${source}" "${destination}" || return 1
	done < <(bundled_dlls)
	for dll in "${OVERRIDDEN_DLLS[@]}"; do
		prefix_wine reg add 'HKCU\Software\Wine\DllOverrides' /v "${dll}" /t REG_SZ /d native,builtin /f || return 1
	done
	prefix_wine wineserver -w 2>/dev/null
	"${CURRENT}/files/bin/wineserver" -w
}

prefix_tweaks_applied() {
	grep -qF '"locationapi"="disabled"' "${PREFIX}/user.reg" 2>/dev/null \
		&& grep -qF '[Software\\Wine\\DXVA2]' "${PREFIX}/user.reg"
}

apply_prefix_tweaks() {
	prefix_wine reg add 'HKCU\Software\Wine\DXVA2' /v backend /t REG_SZ /d va /f \
		&& prefix_wine reg add 'HKCU\Software\Wine\DllOverrides' /v locationapi /t REG_SZ /d disabled /f \
		&& "${CURRENT}/files/bin/wineserver" -w
}

BIN="${HOME}/.local/bin"
UNITS="${HOME}/.config/systemd/user"

sync_script() {
	cat <<'SCRIPT'
#!/usr/bin/env bash
# Mirror the shortcuts Wine programs install into proton_shortcuts onto the desktop
#
# Copies are tagged, so a copy whose source is gone is removed and a hand made launcher is never touched

readonly SOURCE_FOLDER="${HOME}/.wine/drive_c/proton_shortcuts"
readonly ICON_FOLDER="${SOURCE_FOLDER}/icons"
readonly DESKTOP="${HOME}/Desktop"
readonly DRIVE_C="${HOME}/.wine/drive_c"
readonly WINE="${HOME}/.local/bin/wine"
readonly TAG="X-WineShortcutSync-Managed=true"
readonly ICON_SIZES=(256x256 128x128 64x64 48x48 32x32 24x24 16x16)

# Print the value of one key in a .desktop file
desktop_value() {
	awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$1"
}

# Print the Exec line for a Windows path such as C:\Games\game.exe, nothing for anything else
# Writers escape the separators with one, two or four backslashes, so every run becomes one slash
wine_exec() {
	local windows_path="$1"
	[[ "${windows_path}" =~ ^[A-Za-z]:[\\/] ]] || return 0
	printf '%s start /unix "%s"\n' "${WINE}" "$(sed -E 's|\\+|/|g; s|^[A-Za-z]:||' <<< "${windows_path}" \
		| sed "s|^|${DRIVE_C}|")"
}

# Print the largest icon the shortcut bundle extracted for a bare icon name
bundled_icon() {
	local name="$1" size
	[[ -n "${name}" && "${name}" != /* ]] || return 0
	for size in "${ICON_SIZES[@]}"; do
		[[ -f "${ICON_FOLDER}/${size}/apps/${name}.png" ]] || continue
		printf '%s\n' "${ICON_FOLDER}/${size}/apps/${name}.png"
		return 0
	done
}

mirror_shortcut() {
	local source="$1" name copy exec_line icon staged
	name="$(basename "${source}")"
	copy="${DESKTOP}/${name}"
	[[ -f "${copy}" ]] && ! grep -qF "${TAG}" "${copy}" && return 0

	exec_line="$(wine_exec "$(desktop_value "${source}" Exec)")"
	icon="$(bundled_icon "$(desktop_value "${source}" Icon)")"
	staged="$(mktemp -p "${DESKTOP}" ".${name}.XXXXXX")" || return 1
	awk -v exec_line="${exec_line}" -v icon="${icon}" -v tag="${TAG}" '
		/^Exec=/ && exec_line != "" { print "Exec=" exec_line; next }
		/^Icon=/ && icon != "" { print "Icon=" icon; next }
		$0 == tag { tagged = 1 }
		{ print }
		END { if (!tagged) print tag }
	' "${source}" > "${staged}" && chmod 0755 "${staged}" && mv -f "${staged}" "${copy}"
}

remove_orphans() {
	local copy
	for copy in "${DESKTOP}"/*.desktop; do
		grep -qF "${TAG}" "${copy}" || continue
		[[ -f "${SOURCE_FOLDER}/$(basename "${copy}")" ]] || rm -f "${copy}"
	done
}

shopt -s nullglob
mkdir -p "${DESKTOP}"
for shortcut in "${SOURCE_FOLDER}"/*.desktop; do
	mirror_shortcut "${shortcut}"
done
remove_orphans
SCRIPT
}

source_watcher_script() {
	cat <<'SCRIPT'
#!/usr/bin/env bash
# Mirror Wine shortcuts to the desktop now, and again after every change in proton_shortcuts

readonly SOURCE_FOLDER="${HOME}/.wine/drive_c/proton_shortcuts"
readonly SYNC="${HOME}/.local/bin/wine-shortcut-sync"

mkdir -p "${SOURCE_FOLDER}"
"${SYNC}"
inotifywait --monitor --quiet --event create --event close_write --event delete --event moved_from \
	--event moved_to --include '\.desktop$' "${SOURCE_FOLDER}" \
	| while read -r _; do "${SYNC}"; done
SCRIPT
}

desktop_watcher_script() {
	cat <<'SCRIPT'
#!/usr/bin/env bash
# Remove a Wine shortcut when you delete its copy from the desktop

readonly SOURCE_FOLDER="${HOME}/.wine/drive_c/proton_shortcuts"
readonly DESKTOP="${HOME}/Desktop"

mkdir -p "${DESKTOP}"
inotifywait --monitor --quiet --event delete --event moved_from --include '\.desktop$' --format '%f' "${DESKTOP}" \
	| while read -r name; do
		[[ -n "${name}" ]] && rm -f "${SOURCE_FOLDER}/${name}"
	done
SCRIPT
}

# Print a user service that keeps one watcher running
watcher_unit() {
	local description="$1" program="$2"
	printf '[Unit]\nDescription=%s\n\n[Service]\nType=simple\nExecStart=%s\nRestart=on-failure\nRestartSec=5\n' \
		"${description}" "${program}"
	printf '\n[Install]\nWantedBy=default.target\n'
}

source_watch_unit() {
	watcher_unit "Mirror new Wine shortcuts to the desktop" "${BIN}/wine-shortcut-source-watcher"
}

desktop_watch_unit() {
	watcher_unit "Remove a Wine shortcut when its desktop copy is deleted" "${BIN}/wine-shortcut-desktop-watcher"
}

restart_watchers() {
	systemctl --user daemon-reload \
		&& systemctl --user restart wine-shortcut-source-watch.service wine-shortcut-desktop-watch.service
}

task() {
	want::step "Remove the distro Wine packages" sudo no_distro_wine remove_distro_wine
	want::git_branch https://github.com/Winetricks/winetricks.git master "${HOME}/.local/share/winetricks"
	want::symlink "${HOME}/.local/bin/winetricks" "${HOME}/.local/share/winetricks/src/winetricks"
	want::step "Install the newest Proton-GE" "sudo network" newest_proton_active install_newest_proton
	want::symlink "${HOME}/.local/bin/wine" "${CURRENT}/files/bin/wine"
	want::symlink "${HOME}/.local/bin/wineserver" "${CURRENT}/files/bin/wineserver"
	want::step "Create the ~/.wine prefix with drive_c in ~/Windows" "" prefix_ready create_prefix
	want::step "Install ${WINETRICKS_VERBS[*]} with winetricks" network verbs_installed install_verbs
	want::step "Copy Proton-GE's DXVK and VKD3D-Proton into the prefix" "" dlls_deployed deploy_dlls
	want::step "Use VA-API for video and turn off the location service in Wine" "" \
		prefix_tweaks_applied apply_prefix_tweaks
	want::absent "${HOME}/.local/bin/update-proton-ge"
	want::absent "${HOME}/.local/bin/wine64"
	want::handler proton-ge-wine.desktop "Wine (Proton-GE)" wine "${HOME}/.local/bin/wine start /unix %f" \
		"${WINDOWS_TYPES[@]}"
	want::kconfig "${HOME}/Windows/.directory" "Desktop Entry" Icon folder-windows
	want::packages --no-recommends inotify-tools
	want::file "${BIN}/wine-shortcut-sync" sync_script --mode 0755
	want::file "${BIN}/wine-shortcut-source-watcher" source_watcher_script --mode 0755
	want::file "${BIN}/wine-shortcut-desktop-watcher" desktop_watcher_script --mode 0755
	want::file "${UNITS}/wine-shortcut-source-watch.service" source_watch_unit
	want::file "${UNITS}/wine-shortcut-desktop-watch.service" desktop_watch_unit
	want::user_unit wine-shortcut-source-watch.service
	want::user_unit wine-shortcut-desktop-watch.service
	on_change restart_watchers
}
