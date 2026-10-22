// A task's own page with what it does, each step it takes and where each step stands on this machine
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import GeckoUi

PageFrame {
	id: detail

	property string taskId
	readonly property var entry: window.task(taskId)
	readonly property var status: window.statuses[taskId]
	readonly property var steps: status ? status.requirements : (entry ? entry.requirements : [])

	title: entry ? entry.name : ""
	subtitle: entry ? entry.summary : ""
	backText: "‹  " + window.categories[window.step - 1].name
	nextVisible: false
	onBack: window.detailTask = ""

	headerExtra: [
		Toggle {
			enabled: !detail.status || detail.status.status !== "not-applicable"
			checked: window.chosen[detail.taskId] === true
			onToggled: window.setChosen([detail.taskId], checked)
		},
		Text {
			anchors.verticalCenter: parent.verticalCenter
			text: window.chosen[detail.taskId] ? "Queued" : "Skipped"
			color: Theme.text
			font.weight: Font.DemiBold
		}
	]

	Flickable {
		id: detailScroll
		anchors.fill: parent
		clip: true
		contentHeight: stepList.implicitHeight
		rightMargin: 14
		boundsBehavior: Flickable.StopAtBounds
		ScrollBar.vertical: GeckoScrollBar {}

		FastWheel { flickable: detailScroll }

		ColumnLayout {
			id: stepList
			width: detailScroll.width - detailScroll.rightMargin
			spacing: 16

			Rectangle {
				Layout.fillWidth: true
				visible: detail.entry && (detail.entry.conditions.length > 0 || detail.entry.needs.length > 0
					|| detail.entry.restarts.length > 0)
				implicitHeight: notes.implicitHeight + 40
				radius: 16
				color: Theme.surface
				border.color: Theme.line

				Column {
					id: notes
					anchors.fill: parent
					anchors.margins: 20
					spacing: 8

					Repeater {
						model: detail.entry ? detail.entry.conditions : []
						delegate: Text { required property string modelData; text: modelData; color: Theme.text }
					}

					Text {
						visible: detail.entry && detail.entry.needs.indexOf("sudo") >= 0
						text: "Needs your password, asked once for the whole setup"
						color: Theme.text
					}

					Text {
						visible: detail.entry && detail.entry.needs.indexOf("network") >= 0
						text: "Needs an internet connection"
						color: Theme.text
					}

					Repeater {
						model: detail.entry ? detail.entry.restarts : []
						delegate: Text { required property string modelData; text: modelData; color: Theme.warning }
					}
				}
			}

			Text {
				text: "WHAT IT DOES"
				color: Theme.accentHover
				font.pixelSize: Theme.smallSize
				font.weight: Font.DemiBold
				font.letterSpacing: 1
			}

			Repeater {
				model: detail.steps

				delegate: Rectangle {
					id: requirement

					required property var modelData
					readonly property string stepState: modelData.state || ""

					Layout.fillWidth: true
					implicitHeight: 56
					radius: 12
					color: Theme.surface
					border.color: Theme.line

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 18
						anchors.rightMargin: 18
						spacing: 14

						Text {
							text: requirement.stepState === "satisfied" ? "✓"
								: requirement.stepState === "unknown" ? "?" : "•"
							color: requirement.stepState === "satisfied" ? Theme.accentHover : Theme.muted
							font.weight: Font.Bold
						}

						Text {
							Layout.fillWidth: true
							text: requirement.modelData.text
							color: Theme.text
							elide: Text.ElideRight
						}

						Text {
							text: ({
								"satisfied": "In place", "needed": "Will be done",
								"unknown": "Checked during setup", "skipped": "Not needed here"
							})[requirement.stepState] || ""
							color: requirement.stepState === "satisfied" ? Theme.accentHover : Theme.muted
							font.pixelSize: Theme.smallSize
						}
					}
				}
			}
		}
	}
}
