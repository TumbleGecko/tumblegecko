#!/usr/bin/env bash
# name:     No middle-click paste
# summary:  Middle-clicking no longer pastes whatever text was last selected.
# default:  on
#
# This is the System Settings option "Middle-click pastes selected text" under General Behaviour
# Source is kwinrc [Wayland] EnablePrimarySelection in /usr/share/config.kcfg/workspaceoptions_kwinsettings.kcfg

task() {
	want::kconfig kwinrc Wayland EnablePrimarySelection false
	on_change kde::reconfigure_kwin
}
