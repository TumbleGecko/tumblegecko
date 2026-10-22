#!/usr/bin/env bash
# name:     Firefox
# summary:  Firefox as the browser, with uBlock Origin and Bitwarden always installed, DuckDuckGo search, and no AI chat or built-in password saving.
# default:  on
# group:    Internet
#
# Firefox reads enterprise policies from /etc/firefox/policies/policies.json
# Source https://mozilla.github.io/policy-templates/
#
# ExtensionSettings force_installed installs an add-on on first start and keeps it installed
# PasswordManagerEnabled and DisableFormHistory remove the built in storage, because Bitwarden owns that
#
# Preferences with Status "default" only change the starting value, and "locked" ones cannot be changed in Settings
# browser.ml.chat.* is the AI sidebar and the "Ask AI" prompt on selected text
#
# The window rule opens main windows at a fixed size, matched by the title Firefox gives them
# sizerule 3 is Apply initially

firefox_policies() {
	jq -n --arg addons https://addons.mozilla.org/firefox/downloads/latest '{
		policies: {
			PasswordManagerEnabled: false,
			DisableFormHistory: true,
			ExtensionSettings: {
				"uBlock0@raymondhill.net": {
					installation_mode: "force_installed",
					install_url: "\($addons)/ublock-origin/latest.xpi"
				},
				"{446900e4-71c2-419f-a6a7-df9c091e268b}": {
					installation_mode: "force_installed",
					install_url: "\($addons)/bitwarden-password-manager/latest.xpi"
				}
			},
			SearchEngines: { Default: "DuckDuckGo" },
			Preferences: {
				"browser.warnOnQuitShortcut": { Value: false, Status: "default" },
				"general.autoScroll": { Value: true, Status: "default" },
				"media.videocontrols.picture-in-picture.video-toggle.enabled": { Value: false, Status: "default" },
				"browser.ml.chat.enabled": { Value: false, Status: "locked" },
				"browser.ml.chat.shortcuts": { Value: false, Status: "locked" },
				"extensions.formautofill.addresses.enabled": { Value: false, Status: "locked" },
				"extensions.formautofill.creditCards.enabled": { Value: false, Status: "locked" }
			}
		}
	}'
}

task() {
	want::packages --no-recommends MozillaFirefox MozillaFirefox-branding-openSUSE
	want::default_browser firefox.desktop
	want::file /etc/firefox/policies/policies.json firefox_policies --root
	want::kwin_rule firefox "title=— Mozilla Firefox" titlematch=2 sizerule=3 size=2160,1350
}
