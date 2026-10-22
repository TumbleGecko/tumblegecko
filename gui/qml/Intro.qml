// The opening, where the gecko rises out of a pulse of light and the name and the way in follow
import QtQuick
import QtQuick.Effects
import GeckoUi

Rectangle {
	id: intro

	signal begin()

	color: Theme.ground

	Rectangle {
		anchors.fill: parent
		gradient: Gradient {
			GradientStop { position: 0; color: "#14201a" }
			GradientStop { position: 0.7; color: Theme.ground }
		}
		opacity: 0.8
	}

	Column {
		anchors.centerIn: parent
		spacing: 40

		Item {
			id: emblem
			anchors.horizontalCenter: parent.horizontalCenter
			width: 300
			height: 300

			// A soft glow that keeps breathing behind the gecko
			Rectangle {
				id: glow
				anchors.centerIn: parent
				width: parent.width * 1.3
				height: width
				radius: width / 2
				color: Theme.accent
				opacity: 0
				layer.enabled: true
				layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }

				SequentialAnimation on opacity {
					running: true
					loops: Animation.Infinite
					PauseAnimation { duration: 1200 }
					NumberAnimation { to: 0.32; duration: 2400; easing.type: Easing.InOutSine }
					NumberAnimation { to: 0.14; duration: 2400; easing.type: Easing.InOutSine }
				}
			}

			// One ring of light that spreads out as the gecko arrives
			Rectangle {
				id: ring
				anchors.centerIn: parent
				width: parent.width * 0.84
				height: width
				radius: width / 2
				color: "transparent"
				border.color: Theme.accentHover
				border.width: 2
				opacity: 0
				scale: 0.6

				ParallelAnimation {
					running: true
					SequentialAnimation {
						PauseAnimation { duration: 500 }
						NumberAnimation { target: ring; property: "opacity"; to: 0.5; duration: 700 }
						NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 1700 }
					}
					SequentialAnimation {
						PauseAnimation { duration: 500 }
						NumberAnimation {
							target: ring; property: "scale"; to: 1.9; duration: 2400; easing.type: Easing.OutCubic
						}
					}
				}
			}

			Image {
				id: gecko
				anchors.fill: parent
				source: assets + "gecko.png"
				sourceSize: Qt.size(600, 600)
				smooth: true
				opacity: 0
				scale: 0.82
				layer.enabled: true
				layer.effect: MultiEffect {
					maskEnabled: true
					maskSource: round
					maskThresholdMin: 0.5
					maskSpreadAtMin: 1
				}

				ParallelAnimation {
					running: true
					NumberAnimation {
						target: gecko; property: "opacity"; to: 1; duration: 900; easing.type: Easing.OutCubic
					}
					NumberAnimation {
						target: gecko; property: "scale"; to: 1; duration: 1500
						easing.type: Easing.OutBack; easing.overshoot: 1.2
					}
					NumberAnimation {
						target: emblem; property: "anchors.verticalCenterOffset"; from: 40; to: 0; duration: 1500
						easing.type: Easing.OutCubic
					}
				}
			}

			Rectangle {
				id: round
				anchors.fill: gecko
				radius: width / 2
				visible: false
				layer.enabled: true
			}
		}

		Column {
			id: words
			anchors.horizontalCenter: parent.horizontalCenter
			spacing: 16
			opacity: 0

			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				text: "TumbleGecko"
				color: Theme.textStrong
				font.pixelSize: 72
				font.weight: Font.Bold
				font.letterSpacing: -1
			}

			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				width: 560
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
				text: "A safer openSUSE Tumbleweed"
				color: Theme.muted
				font.pixelSize: 20
				lineHeight: 1.3
			}

			SequentialAnimation on opacity {
				running: true
				PauseAnimation { duration: 900 }
				NumberAnimation { to: 1; duration: 900; easing.type: Easing.OutCubic }
			}
		}

		GeckoButton {
			id: beginButton
			anchors.horizontalCenter: parent.horizontalCenter
			primary: true
			text: "Begin setup  →"
			implicitHeight: 56
			opacity: 0
			onClicked: intro.begin()

			SequentialAnimation on opacity {
				running: true
				PauseAnimation { duration: 1600 }
				NumberAnimation { to: 1; duration: 700; easing.type: Easing.OutCubic }
			}
		}
	}
}
