#!/usr/bin/env bash
# name:     No bouncing cursor when starting apps
# summary:  The pointer stays still while an app starts, the taskbar still shows its own starting spinner.
# default:  on
#
# The Launch Feedback dialog shows "None" only when BusyCursor, Blinking and Bouncing are all false
# Source plasma-workspace kcms/cursortheme/ui/LaunchFeedbackDialog.qml
#
# Writing only BusyCursor once left the dialog on "Static", so all three are set

reload_startup_feedback() {
	qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect startupfeedback
}

task() {
	want::kconfig klaunchrc FeedbackStyle BusyCursor false
	want::kconfig klaunchrc BusyCursorSettings Bouncing false
	want::kconfig klaunchrc BusyCursorSettings Blinking false
	on_change reload_startup_feedback
}
