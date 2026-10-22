// The layout every step shares, a heading, the page's own content and Back and Next at the bottom
import QtQuick
import QtQuick.Layouts
import GeckoUi

Item {
	id: frame

	property string title
	property string subtitle
	property string backText: "Back"
	property string nextText: "Continue"
	property bool backVisible: true
	property bool nextVisible: true
	property bool nextEnabled: true
	default property alias content: body.data
	property alias headerExtra: extra.data

	signal back()
	signal next()

	ColumnLayout {
		anchors.fill: parent
		anchors.leftMargin: 64
		anchors.rightMargin: 64
		anchors.topMargin: 48
		anchors.bottomMargin: 32
		spacing: 28

		RowLayout {
			Layout.fillWidth: true
			spacing: 16

			ColumnLayout {
				Layout.fillWidth: true
				spacing: 10

				Text {
					Layout.fillWidth: true
					text: frame.title
					color: Theme.textStrong
					font.pixelSize: Theme.headingSize
					font.weight: Font.Bold
					wrapMode: Text.WordWrap
				}

				Text {
					Layout.fillWidth: true
					visible: frame.subtitle !== ""
					text: Theme.lines(frame.subtitle)
					color: Theme.muted
					font.pixelSize: 18
					lineHeight: 1.3
					wrapMode: Text.WordWrap
				}
			}

			Row {
				id: extra
				spacing: 8
				Layout.alignment: Qt.AlignBottom
			}
		}

		Item {
			id: body
			Layout.fillWidth: true
			Layout.fillHeight: true
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.line
		}

		RowLayout {
			Layout.fillWidth: true

			GeckoButton {
				visible: frame.backVisible
				text: frame.backText
				onClicked: frame.back()
			}

			Item { Layout.fillWidth: true }

			GeckoButton {
				visible: frame.nextVisible
				primary: true
				enabled: frame.nextEnabled
				text: frame.nextText
				onClicked: frame.next()
			}
		}
	}
}
