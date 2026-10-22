#!/usr/bin/env bash
# name:     Panel Colorizer
# summary:  Styles the bottom panel with Panel Colorizer, the widget itself stays invisible.
# default:  on
#
# plasma-panel-colorizer comes from its author's own OBS repository, an accepted third party exception
# Every setting lives in two JSON values, kept in the .globalSettings.json and .configurationOverrides.json beside it
#
# The widget goes on the panel the panel task builds

COLORIZER=luisbocanegra.panel.colorizer
TASK_DIRECTORY="$(dirname "${BASH_SOURCE[0]}")"

colorizer_added() {
	kde::widget_location "${COLORIZER}" >/dev/null
}

add_colorizer() {
	kde::plasma_script "$(cat <<SCRIPT
var all = panels();
for (var i = 0; i < all.length; i++) {
	if (all[i].location === "bottom") {
		var widget = all[i].addWidget("${COLORIZER}");
		widget.currentConfigGroup = ["General"];
		widget.writeConfig("hideWidget", true);
		break;
	}
}
SCRIPT
)" && core::wait_until 10 colorizer_added
}

restart_plasmashell() {
	systemctl --user restart plasma-plasmashell.service
}

task() {
	want::repository home_luisbocanegra \
		https://download.opensuse.org/repositories/home:/luisbocanegra/openSUSE_Tumbleweed/ --priority 99
	want::packages plasma-panel-colorizer
	want::step "Add Panel Colorizer to the bottom panel" "" colorizer_added add_colorizer
	want::widget_setting "${COLORIZER}" "Configuration][General" globalSettings \
		"$(cat "${TASK_DIRECTORY}/050-panel-colorizer.globalSettings.json")"
	want::widget_setting "${COLORIZER}" "Configuration][General" configurationOverrides \
		"$(cat "${TASK_DIRECTORY}/050-panel-colorizer.configurationOverrides.json")"
	on_change restart_plasmashell
}
