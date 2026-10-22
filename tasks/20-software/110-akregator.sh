#!/usr/bin/env bash
# name:     Akregator
# summary:  Installs Akregator, follows 9to5Linux and Phoronix instead of the stock KDE feeds, and waits quietly in the background.
# default:  on
# group:    Internet
#
# Akregator rewrites feeds.opml when it quits, so the list is only written while it is closed
# It is only written when one of these feeds is missing, which on a fresh install replaces the stock KDE feeds
#
# --hide-mainwindow starts it without a window, and its tray icon and ad blocker are set in its own config
# An earlier autostart entry under another name is removed so it does not start twice

FEEDS_FILE="${HOME}/.local/share/akregator/data/feeds.opml"
FEEDS=(
	"9to5Linux|https://9to5linux.com/feed|https://9to5linux.com/"
	"Phoronix|https://www.phoronix.com/rss.php|https://www.phoronix.com/"
)

feeds_opml() {
	local feed title feed_url site_url
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<opml version="1.0">\n <head>\n  <text/>\n </head>\n <body>\n'
	for feed in "${FEEDS[@]}"; do
		IFS='|' read -r title feed_url site_url <<< "${feed}"
		printf '  <outline text="%s" title="%s" type="rss" xmlUrl="%s" htmlUrl="%s"/>\n' \
			"${title}" "${title}" "${feed_url}" "${site_url}"
	done
	printf ' </body>\n</opml>\n'
}

# Feeds you add yourself are kept, only missing ones count
feeds_present() {
	local feed
	for feed in "${FEEDS[@]}"; do
		IFS='|' read -r _ feed_url _ <<< "${feed}"
		grep -qF "xmlUrl=\"${feed_url}\"" "${FEEDS_FILE}" 2>/dev/null || return 1
	done
}

write_feeds() {
	if pgrep -u "$(id -u)" -x akregator >/dev/null; then
		core::error "Akregator is running and would rewrite its feeds when it quits, close it and run this again"
		return 1
	fi
	mkdir -p "$(dirname "${FEEDS_FILE}")" && feeds_opml > "${FEEDS_FILE}"
}

task() {
	want::packages akregator
	want::step "Follow 9to5Linux and Phoronix" "" feeds_present write_feeds
	want::kconfig akregatorrc General "Show Tray Icon" false
	want::kconfig pimpluginsrc NetworkUrlInterceptorPlugins PluginsNetworkUrlInterceptorEnabled \
		webengineviewer_adblockplugin
	want::absent "${HOME}/.config/autostart/akregator.desktop"
	want::autostart org.kde.akregator.desktop --hide-mainwindow
}
