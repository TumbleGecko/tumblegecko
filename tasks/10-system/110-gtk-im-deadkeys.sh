#!/usr/bin/env bash
# name:     Accent keys work in GTK apps
# summary:  Dead keys such as ` ~ ^ ¨ type their characters in GTK 4 apps again.
# default:  on
#
# GTK 4.20 stopped composing dead keys itself on Wayland when no input method runs and leaves it to text-input-v3
# With no input method framework installed GTK 4 apps get nothing, and GTK's own "simple" module composes them again
#
# It is set for the session only, Qt apps ignore it and KDE's keyboard settings are untouched

task() {
	want::session_variable GTK_IM_MODULE simple "${HOME}/.config/environment.d/20-gtk-im.conf"
	restart::if_changed "Accent keys work in GTK apps after you log in again"
}
