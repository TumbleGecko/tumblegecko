#!/usr/bin/env bash
# name:     Telegram
# summary:  Installs Telegram Desktop, which then keeps itself up to date, and starts it quietly in the tray at login.
# default:  on
# group:    Internet
#
# The official Linux build comes from Telegram's own GitHub releases, which carry a sha256 for every file
# Telegram updates itself in place, so /opt/Telegram belongs to you and is only installed when missing
#
# It writes its own launcher and the handler for tg links on first start, so none is written here
# -startintray is the right autostart flag, because -autostart makes a never signed in Telegram quit at once
#
# Its web views for Mini Apps and payments load WebKitGTK when used, and nothing else installs it
# The binary names webkit2gtk and says "Please install WebKitGTK" when it is missing
#
# The NVIDIA crash fix for those web views is session wide, in the NVIDIA task
# The window class carries a per install suffix, so the rule matches it as a regular expression

TELEGRAM=/opt/Telegram

task() {
	want::packages --no-recommends libwebkit2gtk-4_1-0
	want::github_archive telegramdesktop/tdesktop '^td-setup-linux-x64-[0-9.]+\.tar\.xz$' "${TELEGRAM}" \
		--strip 1 --root --yours --self-updating
	want::symlink "${HOME}/.local/bin/telegram" "${TELEGRAM}/Telegram"
	want::autostart_command Telegram "${TELEGRAM}/Telegram -startintray"
	want::kwin_rule '^Telegram org.telegram.desktop._' wmclassmatch=3 wmclasscomplete=true positionrule=4 \
		position:=centered:800x600
}
