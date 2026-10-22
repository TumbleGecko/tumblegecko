"""TumbleGecko installer window.

Starts the bash engine in setup.sh and passes its JSON events to the QML interface, nothing more.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QProcess, QProcessEnvironment, QUrl, Signal, Slot
from PySide6.QtGui import QFontDatabase, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine


ROOT = Path(__file__).resolve().parent.parent
SETUP = ROOT / "setup.sh"
GECKO_UI = ROOT / "gui" / "gecko-ui"
sys.path.insert(0, str(GECKO_UI / "python"))

from gecko_ui.mouse_navigation import MouseNavigation  # noqa: E402
from gecko_ui.root_access import RootAccess  # noqa: E402
EXIT_SUCCESS = 0
EXIT_FAILURE = 1


class EngineCommand(QObject):
	"""One run of setup.sh whose output lines are JSON events."""

	event = Signal(object)
	finished = Signal(int)

	def __init__(self, arguments, environment, parent=None):
		super().__init__(parent)
		self._buffer = b""
		self._process = QProcess(self)
		self._process.setProcessEnvironment(environment)
		self._process.setProcessChannelMode(QProcess.ProcessChannelMode.SeparateChannels)
		self._process.readyReadStandardOutput.connect(self._read_events)
		self._process.finished.connect(self._finish)
		self._process.start(str(SETUP), [*arguments, "--events"])

	def _read_events(self):
		self._buffer += bytes(self._process.readAllStandardOutput())
		*lines, self._buffer = self._buffer.split(b"\n")
		for line in lines:
			if line.strip():
				self.event.emit(json.loads(line))

	def _finish(self, exit_code):
		self._read_events()
		self.finished.emit(exit_code)
		self.deleteLater()


class Engine(QObject):
	"""What the QML interface calls, and the signals it listens to."""

	catalogLoaded = Signal("QVariantList")
	precondition = Signal(dict)
	preconditionsFinished = Signal(bool)
	status = Signal(dict)
	checksFinished = Signal()
	runEvent = Signal(dict)
	runFinished = Signal(bool)

	def __init__(self, parent=None):
		super().__init__(parent)
		self._root = RootAccess("tumblegecko", self)

	def _environment(self):
		environment = QProcessEnvironment.systemEnvironment()
		# The window's own Qt platform must not leak into the KDE tools the engine runs
		environment.remove("QT_QPA_PLATFORM")
		return self._root.add_to(environment)

	def _start(self, arguments, on_event, on_finished):
		command = EngineCommand(arguments, self._environment(), self)
		command.event.connect(on_event)
		command.finished.connect(on_finished)

	@Slot()
	def loadCatalog(self):
		self._start(["--catalog"], self.catalogLoaded.emit, lambda code: None)

	@Slot()
	def checkPreconditions(self):
		self._start(["--preconditions"], self.precondition.emit,
			lambda code: self.preconditionsFinished.emit(code == EXIT_SUCCESS))

	@Slot()
	def checkTasks(self):
		self._start(["--check"], self.status.emit, lambda code: self.checksFinished.emit())

	@Slot(result=bool)
	def needsPassword(self):
		return self._root.needsPassword()

	@Slot(str, result=bool)
	def setPassword(self, password):
		return self._root.setPassword(password)

	@Slot(list)
	def run(self, task_ids):
		self._start(["--run", *task_ids], self.runEvent.emit,
			lambda code: self.runFinished.emit(code == EXIT_SUCCESS))

	@Slot()
	def fixSession(self):
		self._start(["--fix-session"], lambda event: None, lambda code: self.checkPreconditions())

	@Slot(str)
	def showFile(self, path):
		# The file manager opens the folder with the file highlighted, and a plain folder open is the fallback
		shown = subprocess.run(
			["dbus-send", "--session", "--print-reply", "--dest=org.freedesktop.FileManager1",
			"/org/freedesktop/FileManager1", "org.freedesktop.FileManager1.ShowItems",
			f"array:string:{Path(path).as_uri()}", "string:"],
			stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == EXIT_SUCCESS
		if not shown:
			subprocess.Popen(["xdg-open", str(Path(path).parent)])

	@Slot()
	def reboot(self):
		subprocess.Popen(["qdbus6", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot"])


def main():
	# Without a terminal Qt sends its warnings to the journal, which hides why the window failed
	os.environ.setdefault("QT_FORCE_STDERR_LOGGING", "1")
	# Vimix lists fallback icon themes that are not installed, KDE warns about each one and nothing is wrong
	logging_rules = [os.environ.get("QT_LOGGING_RULES"), "kf.iconthemes.warning=false"]
	os.environ["QT_LOGGING_RULES"] = ";".join(filter(None, logging_rules))
	application = QGuiApplication(sys.argv)
	application.setApplicationName("TumbleGecko")
	application.setDesktopFileName("tumblegecko")
	application.setWindowIcon(QIcon(str(GECKO_UI / "assets" / "gecko.png")))

	engine = Engine()
	interface = QQmlApplicationEngine()
	interface.addImportPath(str(GECKO_UI / "qml"))
	interface.rootContext().setContextProperty("engine", engine)
	interface.rootContext().setContextProperty("assets", QUrl.fromLocalFile(str(GECKO_UI / "assets") + "/"))
	interface.rootContext().setContextProperty("monospace",
		QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont).family())
	MouseNavigation(application, interface).attach(interface)
	interface.load(QUrl.fromLocalFile(str(ROOT / "gui" / "qml" / "Main.qml")))
	if not interface.rootObjects():
		return EXIT_FAILURE
	return application.exec()


if __name__ == "__main__":
	sys.exit(main())
