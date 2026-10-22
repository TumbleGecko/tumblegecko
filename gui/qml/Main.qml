// The TumbleGecko window, the intro and then a step by step setup driven by the engine's events
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import GeckoUi

ApplicationWindow {
	id: window

	// Every task from the engine catalog, and the categories they group into, in run order
	property var catalog: []
	property var categories: []
	// Task id to its latest check result
	property var statuses: ({})
	// Task id to whether it is chosen
	property var chosen: ({})
	property bool checking: true
	property bool preconditionsPassed: false
	property var preconditions: []

	// 0 is Welcome, then one step per category, then Review, Install and Done
	property int step: 0
	readonly property int reviewStep: categories.length + 1
	readonly property int installStep: categories.length + 2
	readonly property int doneStep: categories.length + 3
	property string detailTask: ""
	// Where each category's task list was scrolled to, so returning from a task's details keeps the place
	property var categoryScroll: ({})

	// The install run
	property var runOrder: []
	property var runStates: ({})
	property var runLog: []
	// The log file of each task that ran, so the done page can show it
	property var runLogFiles: ({})
	property var restartReasons: []
	property string runningTask: ""
	property bool runSucceeded: false

	width: 1280
	height: 800
	minimumWidth: 900
	minimumHeight: 640
	visible: true
	title: "TumbleGecko"
	color: Theme.ground
	font.family: Theme.font
	font.pixelSize: Theme.bodySize

	function categoryName(id) {
		return id.charAt(0).toUpperCase() + id.slice(1)
	}

	function task(id) {
		return catalog.find(entry => entry.id === id)
	}

	function setChosen(ids, value) {
		const updated = Object.assign({}, chosen)
		ids.forEach(id => updated[id] = value)
		chosen = updated
	}

	function chosenIds() {
		return catalog.filter(entry => chosen[entry.id]).map(entry => entry.id)
	}

	// Root is only needed when a chosen task still has an unfinished step that needs it
	function needsRoot() {
		return chosenIds().some(id => {
			const status = statuses[id]
			const pending = status ? status.requirements.filter(requirement => requirement.state !== "satisfied")
				: task(id).requirements
			return pending.some(requirement => requirement.needs.indexOf("sudo") >= 0)
		})
	}

	function startInstall() {
		runOrder = chosenIds()
		runStates = {}
		runLog = []
		restartReasons = []
		step = installStep
		engine.run(runOrder)
	}

	Connections {
		target: engine

		function onCatalogLoaded(entries) {
			const grouped = []
			const initial = {}
			entries.forEach(entry => {
				let group = grouped.find(category => category.id === entry.category)
				if (!group) {
					group = { id: entry.category, name: categoryName(entry.category), tasks: [] }
					grouped.push(group)
				}
				group.tasks.push(entry.id)
				initial[entry.id] = entry.default
			})
			catalog = entries
			categories = grouped
			chosen = initial
			engine.checkTasks()
		}

		function onStatus(result) {
			const updated = Object.assign({}, statuses)
			updated[result.task] = result
			statuses = updated
			if (result.status === "not-applicable")
				setChosen([result.task], false)
		}

		function onChecksFinished() {
			checking = false
		}

		function onPrecondition(result) {
			preconditions = preconditions.concat([result])
		}

		function onPreconditionsFinished(passed) {
			preconditionsPassed = passed
		}

		function onRunEvent(event) {
			if (event.event === "task") {
				const updated = Object.assign({}, runStates)
				updated[event.task] = event.state === "start" ? "running" : event.result
				runStates = updated
				runningTask = event.state === "start" ? event.name : ""
				if (event.state === "end" && event.log) {
					const files = Object.assign({}, runLogFiles)
					files[event.task] = event.log
					runLogFiles = files
				}
			} else if (event.event === "log") {
				runLog = runLog.concat([event.line]).slice(-400)
			} else if (event.event === "requirement") {
				const marks = {
					"satisfied": "✓ in place", "applied": "✓ done", "failed": "✗ failed", "skipped": "· skipped"
				}
				const mark = marks[event.state] || event.state
				runLog = runLog.concat([mark + "   " + event.text]).slice(-400)
			} else if (event.event === "restart") {
				if (restartReasons.indexOf(event.reason) < 0)
					restartReasons = restartReasons.concat([event.reason])
			}
		}

		function onRunFinished(succeeded) {
			runSucceeded = succeeded
			checking = true
			engine.checkTasks()
		}
	}

	Component.onCompleted: {
		engine.checkPreconditions()
		engine.loadCatalog()
	}

	Intro {
		id: intro
		anchors.fill: parent
		z: 2
		onBegin: hide.start()

		NumberAnimation on opacity {
			id: hide
			running: false
			to: 0
			duration: Theme.calm
			easing.type: Easing.InCubic
			onFinished: intro.visible = false
		}
	}

	RowLayout {
		anchors.fill: parent
		spacing: 0

		// The mouse's back button does what the page's own Back button does, when the page shows one
		MouseBack {
			onBack: {
				if (page.item && page.item.backVisible !== false && page.item.back)
					page.item.back()
			}
		}

		Rail {
			Layout.fillHeight: true
			Layout.preferredWidth: 280
		}

		Loader {
			id: page
			Layout.fillWidth: true
			Layout.fillHeight: true
			sourceComponent: {
				if (window.step === 0)
					return welcomePage
				if (window.step === window.reviewStep)
					return reviewPage
				if (window.step === window.installStep)
					return installPage
				if (window.step === window.doneStep)
					return donePage
				return window.detailTask !== "" ? detailPage : categoryPage
			}

			// Each new page slides in from the right and settles
			onLoaded: {
				item.opacity = 0
				item.x = 40
				enter.restart()
			}

			ParallelAnimation {
				id: enter
				NumberAnimation {
					target: page.item; property: "opacity"; to: 1; duration: Theme.calm; easing.type: Theme.easing
				}
				NumberAnimation {
					target: page.item; property: "x"; to: 0; duration: Theme.calm; easing.type: Theme.easing
				}
			}
		}
	}

	Component { id: welcomePage; WelcomePage {} }
	Component { id: categoryPage; CategoryPage { category: window.categories[window.step - 1] } }
	Component { id: detailPage; DetailPage { taskId: window.detailTask } }
	Component { id: reviewPage; ReviewPage {} }
	Component { id: installPage; InstallPage {} }
	Component { id: donePage; DonePage {} }
}
