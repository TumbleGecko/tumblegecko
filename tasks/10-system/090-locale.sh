#!/usr/bin/env bash
# name:     English system with local formats
# summary:  Keeps menus and messages in English while dates, numbers, money and paper size follow the country of your time zone.
# default:  on
#
# The time zone, not the keyboard, says where the machine is, so it decides the regional LC_* values
# /etc/localtime leads to a zone, zone.tab to its country and locale -a to that country's installed locales
#
# zone.tab is used rather than zone1970.tab because zone1970.tab folds Europe/Stockholm into Berlin
# Sources locale.conf(5) and /usr/share/zoneinfo/zone.tab
#
# A few countries have several installed locales but one clear majority language, picked from the table below
# For bilingual countries such as BE, CH, LU, CA and CY the task refuses and names the choices
#
# The Region and Language page writes ~/.config/plasma-localerc, which hides /etc/locale.conf from KDE apps
# So that file is removed

INTERFACE_LOCALE=en_US.UTF-8
REGIONAL_KEYS=(LC_NUMERIC LC_TIME LC_MONETARY LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION)

declare -A MAJORITY_LOCALE=(
	[DE]=de_DE.UTF-8 [DK]=da_DK.UTF-8 [ES]=es_ES.UTF-8 [FI]=fi_FI.UTF-8 [FR]=fr_FR.UTF-8 [GB]=en_GB.UTF-8
	[IT]=it_IT.UTF-8 [LV]=lv_LV.UTF-8 [NO]=nb_NO.UTF-8 [NZ]=en_NZ.UTF-8 [SE]=sv_SE.UTF-8 [US]=en_US.UTF-8
)

time_zone() {
	local target
	target="$(readlink -f /etc/localtime)" && [[ "${target}" == /usr/share/zoneinfo/* ]] || return 1
	printf '%s\n' "${target#/usr/share/zoneinfo/}"
}

country_of_zone() {
	awk -F'\t' -v zone="$1" '!/^#/ && $3 == zone { print $1; found = 1; exit } END { exit !found }' \
		/usr/share/zoneinfo/zone.tab
}

regional_locale() {
	local zone country locales count
	zone="$(time_zone)" || { core::error "no time zone is set, set one in System Settings, Date & Time"; return 1; }
	country="$(country_of_zone "${zone}")" || { core::error "${zone} belongs to no country"; return 1; }
	locales="$(locale -a | grep -E "_${country}\.utf8$" | sed 's/\.utf8$/.UTF-8/' | sort -u)"
	count="$(grep -c . <<< "${locales}")"
	(( count == 1 )) && { printf '%s\n' "${locales}"; return 0; }
	if (( count > 1 )) && grep -qx -- "${MAJORITY_LOCALE[${country}]:-}" <<< "${locales}"; then
		printf '%s\n' "${MAJORITY_LOCALE[${country}]}"
		return 0
	fi
	core::error "${country} has ${count} matching locales, choose one in MAJORITY_LOCALE:" \
		"$(tr '\n' ' ' <<< "${locales}")"
	return 1
}

locale_conf() {
	local regional key short="${INTERFACE_LOCALE%.*}"
	regional="$(regional_locale)" || return 1
	printf '# TumbleGecko: English interface, %s formats\n' "${regional}"
	printf 'LANG=%s\nLANGUAGE=%s:%s\n' "${INTERFACE_LOCALE}" "${short}" "${short%_*}"
	printf '%s=%s\n' LC_CTYPE "${INTERFACE_LOCALE}" LC_COLLATE "${INTERFACE_LOCALE}" LC_MESSAGES "${INTERFACE_LOCALE}"
	for key in "${REGIONAL_KEYS[@]}"; do
		printf '%s=%s\n' "${key}" "${regional}"
	done
	printf 'LC_ALL=\n'
}

task() {
	want::file /etc/locale.conf locale_conf --root
	want::absent "${HOME}/.config/plasma-localerc"
	restart::if_changed "The new formats apply after you log in again"
}
