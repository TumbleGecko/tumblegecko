// The step list down the left side, showing where you are and what is finished
import QtQuick
import QtQuick.Layouts
import GeckoUi

Rectangle {
	color: Theme.rail

	Rectangle {
		anchors.right: parent.right
		width: 1
		height: parent.height
		color: Theme.line
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: 24
		anchors.topMargin: 32
		spacing: 28

		Row {
			spacing: 12

			Image {
				width: 44
				height: 44
				source: assets + "gecko.png"
				sourceSize: Qt.size(88, 88)
				smooth: true
			}

			Text {
				anchors.verticalCenter: parent.verticalCenter
				text: "TumbleGecko"
				color: Theme.text
				font.pixelSize: 22
				font.weight: Font.Bold
			}
		}

		Column {
			Layout.fillWidth: true
			spacing: 4

			Repeater {
				model: ["Welcome"].concat(window.categories.map(category => category.name), ["Review", "Install"])

				delegate: Rectangle {
					id: row

					required property string modelData
					required property int index
					readonly property int stepNumber: index
					readonly property bool current: window.step === stepNumber
						|| (stepNumber === window.installStep && window.step === window.doneStep)
					readonly property bool done: window.step > stepNumber && !current
					readonly property var categoryTasks: index > 0 && index <= window.categories.length
						? window.categories[index - 1].tasks : []

					width: parent.width
					height: 44
					radius: 10
					color: current ? Theme.raised : "transparent"
					Behavior on color { ColorAnimation { duration: Theme.quick } }

					Row {
						anchors.verticalCenter: parent.verticalCenter
						anchors.left: parent.left
						anchors.leftMargin: 12
						spacing: 12

						Rectangle {
							anchors.verticalCenter: parent.verticalCenter
							width: 18
							height: 18
							radius: 9
							color: row.done ? Theme.accent : "transparent"
							border.width: row.done ? 0 : row.current ? 5 : 2
							border.color: row.current ? Theme.accent : "#3a4a3e"

							Text {
								anchors.centerIn: parent
								visible: row.done
								text: "✓"
								color: Theme.textOnAccent
								font.pixelSize: Theme.smallSize
								font.weight: Font.Bold
							}
						}

						Text {
							anchors.verticalCenter: parent.verticalCenter
							text: row.modelData
							color: row.current ? Theme.textStrong : row.done ? "#d5e2d8" : Theme.muted
							font.weight: row.current ? Font.DemiBold : Font.Normal
						}
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						anchors.right: parent.right
						anchors.rightMargin: 12
						visible: row.categoryTasks.length > 0
						text: row.categoryTasks.filter(id => window.chosen[id]).length
						color: Theme.muted
						font.pixelSize: Theme.smallSize
					}
				}
			}
		}

		Item { Layout.fillHeight: true }
	}
}
