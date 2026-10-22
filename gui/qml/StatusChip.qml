// A small label for where a task stands on this machine
import QtQuick
import GeckoUi

Rectangle {
	property string status: ""

	readonly property var look: ({
		"done": ["Already set up", Theme.accentHover, Theme.doneFill],
		"needed": ["Not set up yet", "#d9e4dc", "#24302a"],
		"unknown": ["Checked during setup", Theme.warning, "#3a3020"],
		"not-applicable": ["Not needed here", Theme.muted, "#1a221d"],
		"failed": ["Could not check", Theme.danger, "#3a2020"]
	})[status] || ["Checking", Theme.muted, "#1a221d"]

	implicitWidth: label.implicitWidth + 24
	implicitHeight: 28
	radius: height / 2
	color: look[2]

	Text {
		id: label
		anchors.centerIn: parent
		text: parent.look[0]
		color: parent.look[1]
		font.pixelSize: Theme.smallSize
		font.weight: Font.Medium
	}
}
