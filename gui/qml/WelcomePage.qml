// The first step, which checks that this machine is one TumbleGecko knows how to handle safely
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import GeckoUi

PageFrame {
	title: window.preconditionsPassed || window.preconditions.length === 0
		? "Let's check this machine first" : "This machine needs a change first"
	subtitle: "TumbleGecko only changes systems it knows how to handle safely. "
		+ "Everything below has to pass before you pick what to set up."
	backVisible: false
	nextEnabled: window.preconditionsPassed
	onNext: window.step = 1

	ListView {
		id: checks
		anchors.fill: parent
		spacing: 10
		clip: true
		model: window.preconditions
		ScrollBar.vertical: GeckoScrollBar {}

		FastWheel { flickable: checks }

		delegate: Rectangle {
			id: check

			required property var modelData
			required property int index

			width: ListView.view.width
			height: 64
			radius: 14
			color: Theme.surface
			border.color: Theme.line
			opacity: 0

			NumberAnimation on opacity {
				running: true
				from: 0
				to: 1
				duration: Theme.calm
				easing.type: Theme.easing
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 20
				anchors.rightMargin: 20
				spacing: 16

				Rectangle {
					Layout.preferredWidth: 32
					Layout.preferredHeight: 32
					radius: 16
					color: check.modelData.ok ? Theme.doneFill : Theme.warningFill

					Text {
						anchors.centerIn: parent
						text: check.modelData.ok ? "✓" : "!"
						color: check.modelData.ok ? Theme.accentHover : Theme.warning
						font.weight: Font.Bold
					}
				}

				Text {
					text: check.modelData.name
					color: Theme.text
					font.pixelSize: 18
					font.weight: Font.DemiBold
					Layout.preferredWidth: 160
				}

				Text {
					Layout.fillWidth: true
					text: check.modelData.detail
					color: Theme.muted
					elide: Text.ElideRight
				}

				GeckoButton {
					visible: check.modelData.fix === "session"
					text: "Switch to Wayland"
					onClicked: {
						window.preconditions = []
						engine.fixSession()
					}
				}

				Text {
					visible: check.modelData.fix !== "session"
					text: check.modelData.ok ? "Passed" : "Not supported"
					color: check.modelData.ok ? Theme.accentHover : Theme.warning
					font.pixelSize: Theme.smallSize
					font.weight: Font.DemiBold
				}
			}
		}
	}
}
