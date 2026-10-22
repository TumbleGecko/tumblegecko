#!/usr/bin/env bash
# name:     Dark GTK apps
# summary:  GTK and GNOME apps follow the dark theme too, not only KDE ones.
# default:  on
#
# GTK 4 apps and browsers already follow Plasma through xdg-desktop-portal-kde
# libadwaita apps read the gsettings color-scheme and Breeze themed GTK 3 apps read settings.ini, so both are set

task() {
	want::gsettings org.gnome.desktop.interface color-scheme prefer-dark
	want::ini_key "${HOME}/.config/gtk-3.0/settings.ini" Settings gtk-application-prefer-dark-theme true
	want::ini_key "${HOME}/.config/gtk-4.0/settings.ini" Settings gtk-application-prefer-dark-theme true
}
