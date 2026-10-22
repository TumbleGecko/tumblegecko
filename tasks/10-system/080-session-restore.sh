#!/usr/bin/env bash
# name:     Start each login with a clean desktop
# summary:  Windows from the last session are only reopened if you saved the session on purpose.
# default:  on
#
# Plasma's default restorePreviousLogout reopens whatever was left open at logout
# restoreSavedSession is "When session was manually saved" in System Settings, Session
#
# The value was checked against kcm_smserver.so on 2026-05-26

task() {
	want::kconfig ksmserverrc General loginMode restoreSavedSession --notify
}
