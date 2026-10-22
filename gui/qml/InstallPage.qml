// Setup running, with overall progress, each task as it goes and the live log on request
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import GeckoUi

Item {
	id: install

	readonly property int finished: window.runOrder.filter(
		id => window.runStates[id] && window.runStates[id] !== "running").length
	readonly property bool running: finished < window.runOrder.length
	property bool showLog: true

	ColumnLayout {
		anchors.fill: parent
		anchors.leftMargin: 64
		anchors.rightMargin: 64
		anchors.topMargin: 40
		anchors.bottomMargin: 32
		spacing: 24

		RowLayout {
			spacing: 24

			Item {
				Layout.preferredWidth: 88
				Layout.preferredHeight: 88

				Rectangle {
					anchors.centerIn: parent
					width: 120
					height: 120
					radius: 60
					color: Theme.accent
					layer.enabled: true
					layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }

					SequentialAnimation on opacity {
						running: install.running
						loops: Animation.Infinite
						NumberAnimation { from: 0.15; to: 0.4; duration: 1600; easing.type: Easing.InOutSine }
						NumberAnimation { from: 0.4; to: 0.15; duration: 1600; easing.type: Easing.InOutSine }
					}
				}

				Image {
					anchors.fill: parent
					source: assets + "gecko.png"
					sourceSize: Qt.size(176, 176)
					smooth: true
				}
			}

			ColumnLayout {
				spacing: 8

				Text {
					text: install.running ? "Setting things up" : "All done"
					color: Theme.textStrong
					font.pixelSize: Theme.headingSize
					font.weight: Font.Bold
				}

				Text {
					text: install.running ? (window.runningTask ? "Now: " + window.runningTask : "Starting…")
						: "Every chosen task has run."
					color: Theme.muted
					font.pixelSize: 18
				}
			}
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 8

			ProgressBar {
				id: progress
				Layout.fillWidth: true
				from: 0
				to: Math.max(1, window.runOrder.length)
				value: install.finished
				Accessible.name: "Setup progress"

				Behavior on value { NumberAnimation { duration: 600; easing.type: Theme.easing } }

				background: Rectangle { implicitHeight: 14; radius: 7; color: "#1a241d" }
				contentItem: Item {
					Rectangle {
						width: progress.visualPosition * parent.width
						height: parent.height
						radius: 7
						color: Theme.accent
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true

				Text {
					Layout.fillWidth: true
					text: install.finished + " of " + window.runOrder.length
						+ (window.runOrder.length === 1 ? " task" : " tasks")
					color: Theme.muted
					font.pixelSize: Theme.smallSize
				}

				Text {
					text: Math.round(100 * install.finished / Math.max(1, window.runOrder.length)) + "%"
					color: Theme.muted
					font.pixelSize: Theme.smallSize
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.fillHeight: true
			spacing: 16

			Rectangle {
				Layout.fillWidth: true
				Layout.fillHeight: true
				radius: 16
				color: Theme.rail
				border.color: Theme.line

				ListView {
					id: tasks
					anchors.fill: parent
					anchors.margins: 8
					clip: true
					model: window.runOrder
					currentIndex: window.runOrder.findIndex(id => window.runStates[id] === "running")
					highlightFollowsCurrentItem: true
					highlightMoveDuration: Theme.calm
					ScrollBar.vertical: GeckoScrollBar {}

					FastWheel { flickable: tasks }

					delegate: Item {
						id: row

						required property string modelData
						readonly property string runState: window.runStates[modelData] || ""

						width: tasks.width
						height: 44

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 12
							anchors.rightMargin: 12
							spacing: 14

							Item {
								Layout.preferredWidth: 24
								Layout.preferredHeight: 24

								BusyIndicator {
									anchors.fill: parent
									running: row.runState === "running"
									visible: running
								}

								Rectangle {
									anchors.fill: parent
									radius: 12
									visible: row.runState !== "running"
									color: row.runState === "" ? "transparent"
										: row.runState === "failed" ? "#3a2020" : Theme.accent
									border.width: row.runState === "" ? 2 : 0
									border.color: "#2c3a30"

									Text {
										anchors.centerIn: parent
										visible: row.runState !== ""
										text: row.runState === "failed" ? "!" : "✓"
										color: row.runState === "failed" ? Theme.danger : Theme.textOnAccent
										font.pixelSize: Theme.smallSize
										font.weight: Font.Bold
									}
								}
							}

							Text {
								Layout.fillWidth: true
								text: window.task(row.modelData) ? window.task(row.modelData).name : row.modelData
								color: row.runState === "running" ? Theme.textStrong
									: row.runState === "" ? Theme.muted : "#d5e2d8"
								font.weight: row.runState === "running" ? Font.DemiBold : Font.Normal
								elide: Text.ElideRight
							}

							Text {
								text: ({ "running": "Working", "changed": "Done", "already-done": "Already in place",
									"not-applicable": "Not needed", "failed": "Needs a look" })[row.runState] || ""
								color: row.runState === "failed" ? Theme.danger : Theme.muted
								font.pixelSize: Theme.smallSize
							}
						}
					}
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.fillHeight: true
				visible: install.showLog
				radius: 16
				color: "#070a08"
				border.color: Theme.line

				ListView {
					id: log
					anchors.fill: parent
					anchors.margins: 16
					clip: true
					model: window.runLog
					onCountChanged: positionViewAtEnd()
					ScrollBar.vertical: GeckoScrollBar {}

					FastWheel { flickable: log }

					delegate: Text {
						required property string modelData
						width: log.width
						text: modelData
						color: "#b9c9bd"
						font.family: monospace
						font.pixelSize: Theme.smallSize
						wrapMode: Text.WrapAnywhere
					}
				}
			}
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.line
		}

		RowLayout {
			Layout.fillWidth: true

			GeckoButton {
				text: install.showLog ? "Hide details" : "Show details"
				onClicked: install.showLog = !install.showLog
			}

			Item { Layout.fillWidth: true }

			GeckoButton {
				visible: !install.running
				primary: true
				text: "Continue"
				onClicked: window.step = window.doneStep
			}
		}
	}
}
