#!/usr/bin/env bash
# name:     Bottom panel
# summary:  One bottom panel with the TumbleGecko launcher on the left, centered task icons, then the tray, the clock with ISO dates and week numbers, and show desktop.
# default:  on
#
# Building the panel removes every existing panel first, the same as the panel templates Plasma ships
# It is built from Plasma's own defaultPanel template through plasmashell's evaluateScript
#
# Plasma writes the new panel to its config in its own time, so the task waits for it before setting the widgets
# Pinned apps are Dolphin and Firefox, and network, brightness, clipboard and media sit hidden in the tray
#
# Which items the tray shows at all is left to Plasma, because apps such as KDE Connect add themselves there
#
# The launcher shows the TumbleGecko gecko, white like the panel's other symbols on its dark background
# The coloured gecko and a black one for light panels are installed beside it, in the user's hicolor icon folder

PANEL_SCRIPT="$(cat <<'SCRIPT'
// Wipe every existing panel.
var existing = panels();
for (var i = 0; i < existing.length; i++) {
	existing[i].remove();
}

// Build the bottom panel.
var p = new Panel;
p.location = "bottom";
p.floating = false;
p.height = 46;

// 21:9 max-width clamp (carried over from the upstream defaultPanel template).
var maximumAspectRatio = 21/9;
if (p.formFactor === "horizontal") {
	var geo = screenGeometry(p.screen);
	var maximumWidth = Math.ceil(geo.height * maximumAspectRatio);
	if (geo.width > maximumWidth) {
		p.alignment = "center";
		p.minimumLength = maximumWidth;
		p.maximumLength = maximumWidth;
	}
}

p.addWidget("org.kde.plasma.kickoff");
p.addWidget("org.kde.plasma.panelspacer");
p.addWidget("org.kde.plasma.icontasks");
p.addWidget("org.kde.plasma.panelspacer");
p.addWidget("org.kde.plasma.marginsseparator");
p.addWidget("org.kde.plasma.systemtray");
p.addWidget("org.kde.plasma.digitalclock");
p.addWidget("org.kde.plasma.showdesktop");

"OK";
SCRIPT
)"
ICONS="${HOME}/.local/share/icons/hicolor"
GECKO_ASSETS="${TUMBLEGECKO_ROOT}/gui/gecko-ui/assets"

gecko_icon() {
	cat "${GECKO_ASSETS}/gecko.png"
}

gecko_symbolic_white() {
	cat "${GECKO_ASSETS}/gecko-symbolic.png"
}

gecko_symbolic_black() {
	cat "${GECKO_ASSETS}/gecko-symbolic-black.png"
}

HIDDEN_TRAY_ITEMS=org.kde.plasma.networkmanagement,org.kde.plasma.brightness,org.kde.plasma.clipboard
HIDDEN_TRAY_ITEMS+=,org.kde.plasma.mediacontroller

panel_built() {
	local widget
	for widget in kickoff icontasks systemtray digitalclock showdesktop; do
		kde::widget_location "org.kde.plasma.${widget}" >/dev/null || return 1
	done
	(( $(grep -Fxc plugin=org.kde.plasma.panelspacer "${HOME}/.config/${KDE_APPLETS_FILE}") >= 2 ))
}

build_panel() {
	kde::plasma_script "${PANEL_SCRIPT}" && core::wait_until 10 panel_built
}

restart_plasmashell() {
	systemctl --user restart plasma-plasmashell.service
}

task() {
	want::step "Build the bottom panel" "" panel_built build_panel
	want::widget_setting org.kde.plasma.icontasks "Configuration][General" launchers \
		applications:org.kde.dolphin.desktop,applications:firefox.desktop
	want::widget_setting org.kde.plasma.icontasks "Configuration][General" interactiveMute false
	want::widget_setting org.kde.plasma.digitalclock "Configuration][Appearance" autoFontAndSize false
	want::widget_setting org.kde.plasma.digitalclock "Configuration][Appearance" dateFormat isoDate
	want::widget_setting org.kde.plasma.digitalclock "Configuration][Appearance" fontFamily "Noto Sans"
	want::widget_setting org.kde.plasma.digitalclock "Configuration][Appearance" fontStyleName Medium
	want::widget_setting org.kde.plasma.digitalclock "Configuration][Appearance" fontWeight 500
	want::widget_setting org.kde.plasma.digitalclock "Configuration][Appearance" showWeekNumbers true
	want::widget_setting org.kde.plasma.systemtray General hiddenItems "${HIDDEN_TRAY_ITEMS}"
	want::file "${ICONS}/512x512/apps/tumblegecko.png" gecko_icon
	want::file "${ICONS}/256x256/apps/tumblegecko-symbolic.png" gecko_symbolic_white
	want::file "${ICONS}/256x256/apps/tumblegecko-symbolic-black.png" gecko_symbolic_black
	want::widget_setting org.kde.plasma.kickoff "Configuration][General" icon tumblegecko-symbolic
	on_change restart_plasmashell
}
