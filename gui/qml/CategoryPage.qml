// One category, every task in it as a card you can switch on or off or open for its details
import QtQuick
import QtQuick.Controls.Basic
import GeckoUi

PageFrame {
	id: categoryPage

	property var category

	readonly property int chosenCount: category ? category.tasks.filter(id => window.chosen[id]).length : 0

	title: category ? category.name : ""
	subtitle: chosenCount + " of " + (category ? category.tasks.length : 0)
		+ " chosen. Anything already set up is checked again and left alone."
	nextText: window.step + 1 === window.reviewStep ? "Review" : "Next: " + window.categories[window.step].name
	onBack: window.step -= 1
	onNext: window.step += 1

	headerExtra: [
		GeckoButton {
			text: "Choose all"
			onClicked: window.setChosen(categoryPage.category.tasks.filter(
				id => window.statuses[id]?.status !== "not-applicable"), true)
		},
		GeckoButton {
			text: "Choose none"
			onClicked: window.setChosen(categoryPage.category.tasks, false)
		}
	]

	// The category's tasks in groups, each group in the order its first task runs
	// What is off by default comes first, its groups at the top and its tasks first in them, so it is seen
	// Next keeps this page and only changes its category, so the new list starts at its top
	onCategoryChanged: list.contentY = 0

	readonly property var groups: {
		if (!category)
			return []
		const ordered = []
		for (const id of category.tasks) {
			const name = window.task(id).group
			let group = ordered.find(entry => entry.name === name)
			if (!group) {
				group = { name: name, tasks: [] }
				ordered.push(group)
			}
			group.tasks.push(id)
		}
		// QML's sort may reorder ties, so run order breaks them
		const runOrder = category.tasks
		for (const group of ordered) {
			group.tasks.sort((a, b) => (window.task(a).default - window.task(b).default)
				|| (runOrder.indexOf(a) - runOrder.indexOf(b)))
		}
		const hasOptional = group => group.tasks.some(id => !window.task(id).default)
		const position = group => Math.min(...group.tasks.map(id => runOrder.indexOf(id)))
		return ordered.slice().sort((a, b) => (hasOptional(b) - hasOptional(a)) || (position(a) - position(b)))
	}

	Flickable {
		id: list

		readonly property int columns: Math.max(1, Math.floor((width - rightMargin) / 460))
		readonly property real cardWidth: (width - rightMargin - (columns - 1) * 12) / columns

		anchors.fill: parent
		clip: true
		contentWidth: width
		contentHeight: groupColumn.height
		boundsBehavior: Flickable.StopAtBounds
		rightMargin: 14
		ScrollBar.vertical: GeckoScrollBar {}

		FastWheel { flickable: list }

		// The page is rebuilt after a task's details, so it takes the list back to where it was
		function restoreScroll() {
			const saved = categoryPage.category ? window.categoryScroll[categoryPage.category.name] : undefined
			if (saved !== undefined)
				contentY = saved
		}

		Component.onCompleted: Qt.callLater(restoreScroll)
		Component.onDestruction: {
			if (categoryPage.category)
				window.categoryScroll[categoryPage.category.name] = contentY
		}

		Column {
			id: groupColumn
			width: list.width - list.rightMargin
			spacing: 28

			Repeater {
				model: categoryPage.groups

				delegate: Column {
					required property var modelData
					width: groupColumn.width
					spacing: 12

					Text {
						visible: modelData.name !== ""
						text: modelData.name.toUpperCase()
						color: Theme.accentHover
						font.pixelSize: Theme.smallSize
						font.weight: Font.DemiBold
						font.letterSpacing: 1
					}

					Grid {
						columns: list.columns
						spacing: 12

						Repeater {
							model: modelData.tasks

							delegate: TaskCard {
								required property string modelData
								width: list.cardWidth
								height: 172
								taskId: modelData
							}
						}
					}
				}
			}
		}
	}
}
