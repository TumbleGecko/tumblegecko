// A task as a card with its switch, name, one line about it, its state here and the way into its details
import QtQuick
import QtQuick.Layouts
import GeckoUi

Rectangle {
	id: card

	property string taskId
	readonly property var entry: window.task(taskId)
	readonly property var status: window.statuses[taskId]
	readonly property bool on: window.chosen[taskId] === true
	readonly property bool available: !status || status.status !== "not-applicable"

	radius: 16
	color: on ? "#142019" : Theme.rail
	border.color: hover.hovered ? "#355040" : on ? Theme.lineStrong : Theme.line
	opacity: available ? 1 : 0.6
	Behavior on color { ColorAnimation { duration: Theme.quick } }
	Behavior on border.color { ColorAnimation { duration: Theme.quick } }

	HoverHandler { id: hover }

	RowLayout {
		anchors.fill: parent
		anchors.margins: 18
		spacing: 14

		Toggle {
			Layout.alignment: Qt.AlignTop
			enabled: card.available
			checked: card.on
			Accessible.name: "Include " + (card.entry ? card.entry.name : "")
			onToggled: window.setChosen([card.taskId], checked)
		}

		ColumnLayout {
			Layout.fillWidth: true
			Layout.fillHeight: true
			spacing: 6

			Text {
				Layout.fillWidth: true
				text: card.entry ? card.entry.name : ""
				color: Theme.text
				font.pixelSize: 18
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			Text {
				Layout.fillWidth: true
				Layout.fillHeight: true
				text: card.entry ? Theme.lines(card.entry.summary) : ""
				color: Theme.muted
				font.pixelSize: Theme.smallSize
				wrapMode: Text.WordWrap
				elide: Text.ElideRight
				lineHeight: 1.2
			}

			RowLayout {
				Layout.fillWidth: true

				StatusChip {
					status: card.status ? card.status.status : ""
				}

				Item { Layout.fillWidth: true }

				GeckoButton {
					implicitHeight: 36
					leftPadding: 16
					rightPadding: 16
					font.pixelSize: Theme.smallSize
					text: "More info  ›"
					onClicked: window.detailTask = card.taskId
				}
			}
		}
	}
}
