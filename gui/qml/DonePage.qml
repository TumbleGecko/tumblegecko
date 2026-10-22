// The end, with what was done, what needs a look and whether a restart finishes anything
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import GeckoUi

Item {
	readonly property var results: window.runOrder.map(id => window.runStates[id])
	readonly property var failedTasks: window.runOrder.filter(id => window.runStates[id] === "failed")

	Flickable {
		id: page
		anchors.fill: parent
		clip: true
		contentWidth: width
		contentHeight: Math.max(height, summary.implicitHeight + 96)
		boundsBehavior: Flickable.StopAtBounds
		ScrollBar.vertical: GeckoScrollBar {}

		FastWheel { flickable: page }

		ColumnLayout {
			id: summary
			x: (page.width - width) / 2
			y: Math.max(48, (page.height - implicitHeight) / 2)
			width: Math.min(page.width - 96, 760)
			spacing: 28

			Image {
				id: gecko
				Layout.alignment: Qt.AlignHCenter
				Layout.preferredWidth: 168
				Layout.preferredHeight: 168
				source: assets + "gecko.png"
				sourceSize: Qt.size(336, 336)
				smooth: true
				NumberAnimation on scale { from: 0.85; to: 1; duration: 900; easing.type: Easing.OutBack }
			}

			Text {
				Layout.alignment: Qt.AlignHCenter
				text: failedTasks.length === 0 ? "Your Tumbleweed is ready" : "Almost there"
				color: Theme.textStrong
				font.pixelSize: 52
				font.weight: Font.Bold
			}

			Text {
				Layout.alignment: Qt.AlignHCenter
				Layout.fillWidth: true
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
				text: Theme.lines("Run TumbleGecko again any time. It only changes what has drifted.")
				color: Theme.muted
				font.pixelSize: 19
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 12

				Repeater {
					model: [
						[results.filter(result => result === "changed").length, "Set up now", Theme.accentHover],
						[results.filter(result => result === "already-done" || result === "not-applicable").length,
							"Already in place", Theme.text],
						[failedTasks.length, "Need a look", Theme.warning]
					]

					delegate: Rectangle {
						required property var modelData

						Layout.fillWidth: true
						implicitHeight: 104
						radius: 16
						color: Theme.surface
						border.color: Theme.line

						Column {
							anchors.centerIn: parent
							spacing: 4

							Text {
								anchors.horizontalCenter: parent.horizontalCenter
								text: modelData[0]
								color: modelData[2]
								font.pixelSize: 40
								font.weight: Font.Bold
							}
							Text {
								anchors.horizontalCenter: parent.horizontalCenter
								text: modelData[1]
								color: Theme.muted
							}
						}
					}
				}
			}

			Repeater {
				model: failedTasks

				delegate: Rectangle {
					required property string modelData

					Layout.fillWidth: true
					implicitHeight: 60
					radius: 14
					color: Theme.warningFill
					border.color: Theme.warningLine

					Text {
						anchors.verticalCenter: parent.verticalCenter
						anchors.left: parent.left
						anchors.leftMargin: 18
						anchors.right: showLogs.left
						anchors.rightMargin: 12
						elide: Text.ElideRight
						text: window.task(modelData).name + " did not finish"
						color: Theme.warning
					}

					GeckoButton {
						id: showLogs
						anchors.verticalCenter: parent.verticalCenter
						anchors.right: parent.right
						anchors.rightMargin: 14
						visible: window.runLogFiles[modelData] !== undefined
						text: "Show logs"
						onClicked: engine.showFile(window.runLogFiles[modelData])
					}
				}
			}

			Rectangle {
				Layout.fillWidth: true
				visible: window.restartReasons.length > 0
				implicitHeight: reasons.implicitHeight + 36
				radius: 14
				color: Theme.surface
				border.color: Theme.line

				Column {
					id: reasons
					anchors.fill: parent
					anchors.margins: 18
					spacing: 8

					Text {
						text: "A RESTART FINISHES THESE"
						color: Theme.accentHover
						font.pixelSize: Theme.smallSize
						font.weight: Font.DemiBold
						font.letterSpacing: 1
					}

					Repeater {
						model: window.restartReasons
						delegate: Text {
							required property string modelData
							width: reasons.width
							text: "•  " + modelData
							color: Theme.text
							wrapMode: Text.WordWrap
						}
					}
				}
			}

			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: 12

				GeckoButton {
					text: window.restartReasons.length > 0 ? "Restart later" : "Close"
					onClicked: Qt.quit()
				}

				GeckoButton {
					visible: window.restartReasons.length > 0
					primary: true
					text: "Restart now"
					onClicked: engine.reboot()
				}
			}
		}
	}
}
