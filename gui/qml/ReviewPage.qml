// The last look before anything changes, what runs and what setup will need from you
import QtQuick
import QtQuick.Layouts
import GeckoUi

PageFrame {
	id: review

	readonly property int total: window.chosenIds().length

	title: "Ready to set up"
	subtitle: (total === 1 ? "1 task runs" : total + " tasks run in this order")
		+ ". Anything already in place is checked again and left alone."
	nextText: "Start setup  →"
	nextEnabled: total > 0 && !window.checking
	onBack: window.step -= 1
	onNext: {
		if (window.needsRoot() && engine.needsPassword())
			password.open()
		else
			window.startInstall()
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 20

		Rectangle {
			Layout.fillWidth: true
			Layout.maximumWidth: 820
			implicitHeight: groups.implicitHeight
			radius: 16
			color: Theme.surface
			border.color: Theme.line
			clip: true

			Column {
				id: groups
				width: parent.width

				Repeater {
					model: window.categories

					delegate: Rectangle {
						required property var modelData
						required property int index

						width: groups.width
						height: 60
						color: "transparent"

						Rectangle {
							visible: index > 0
							width: parent.width
							height: 1
							color: "#1d2820"
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 22
							anchors.rightMargin: 12

							Text {
								Layout.fillWidth: true
								text: modelData.name
								color: Theme.text
								font.pixelSize: 18
								font.weight: Font.DemiBold
							}

							Text {
								text: modelData.tasks.filter(id => window.chosen[id]).length
									+ " of " + modelData.tasks.length
								color: Theme.muted
							}

							GeckoButton {
								text: "Change"
								onClicked: window.step = index + 1
							}
						}
					}
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.maximumWidth: 820
			spacing: 12

			Repeater {
				model: [
					["Your password is asked once, right when setup starts"],
					["Stay online, apps come from their newest releases"],
					["Some changes ask for a restart once everything is done"]
				]

				delegate: Rectangle {
					required property var modelData

					Layout.fillWidth: true
					implicitHeight: 76
					radius: 14
					color: Theme.surface
					border.color: Theme.line

					Text {
						anchors.fill: parent
						anchors.margins: 16
						text: modelData[0]
						color: Theme.text
						wrapMode: Text.WordWrap
						verticalAlignment: Text.AlignVCenter
					}

				}
			}
		}

		Text {
			visible: window.checking
			text: "Still checking what is already in place…"
			color: Theme.muted
		}

		Item { Layout.fillHeight: true }
	}

	PasswordDialog {
		id: password
		appName: "TumbleGecko"
		reason: "Installing system software needs it."
		actionText: "Start setup"
		checkPassword: entered => engine.setPassword(entered)
		onAccepted: window.startInstall()
	}
}
