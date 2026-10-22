# TumbleGecko design

## Commands

Without arguments `setup.sh` opens the window, and these run the engine from a terminal instead.

```sh
./setup.sh --list                   # every task and its id
./setup.sh --check                  # what still has work to do, changes nothing
./setup.sh --run software/foot      # set up chosen tasks
./setup.sh --run --all              # set up every task that is on by default
```

`--events` prints the same JSON events the window reads.

## Layers

`setup.sh` is the one entry point.\
With no arguments it installs the window's own packages by capability and starts `gui/tumblegecko.py`, otherwise it runs an engine command and prints its events.

`lib/core.sh` holds logging, the JSON event writer, running things as root and small system queries.\
`lib/task.sh` is the runtime a task's declarations run inside.\
`lib/engine.sh` finds tasks, runs them in a mode and turns their output into events.\
`lib/preconditions.sh` refuses machines TumbleGecko does not support.\
`lib/components/*.sh` are the building blocks tasks declare with.

## Tasks

A task is `tasks/<NN>-<category>/<NNN>-<name>.sh`.\
Its id is the category and name without their numbers, such as `software/foot`, and the numbers set the run order.\
Its header carries `name`, `summary`, `default` (on or off) and an optional `group`, which the window shows as a heading within the category.\
Comments with the reasons and sources follow.\
Its only code is a `task()` function, and the helper functions that function's steps use.

```bash
task() {
	when::pci_vendor 10de "Only on machines with an NVIDIA graphics card"
	want::packages --no-recommends openSUSE-repos-Tumbleweed-NVIDIA
	want::newest_numbered_package nvidia-open-driver-G -signed-kmp-meta 'nvidia-gl-G{N}-32bit'
	restart::if_changed "The NVIDIA driver takes over on the next boot"
}
```

## Modes

The engine sources the task in a subshell with `TASK_MODE` set and calls `task()`.\
Every `want::` call ends in `task::requirement`, which acts by mode.

In `describe` it only reports the step's text and what it needs, sudo or network, which builds the catalog.\
In `check` it runs the step's check function, 0 is satisfied, `CORE_EXIT_UNKNOWN` is cannot tell and anything else is needed, and changes nothing.\
In `apply` a satisfied step is skipped, otherwise its apply function runs and the check must pass afterwards, or the step fails and the rest of the task is skipped.

Checks never ask for a password.\
`core::as_root` uses `sudo -n` outside `apply`, and components never query a polkit protected service as the user.

`when::` conditions mark a task not needed on this machine.\
`restart::if_changed` and `on_change` only act when this run changed something.\
`say` gives the next step a friendlier text.

## Events

Every command prints one JSON object per line, which the window reads and `engine::present` turns into text.

`precondition` carries name, ok, detail and an optional fix.\
`status` carries a task's check result, its overall status and each step's text, needs and state.\
`run`, `task` and `requirement` follow an install, `log` carries the task's output, `restart` a reason to restart.\
The catalog is one JSON array with each task's id, category, group, name, summary, default, steps, conditions, restart reasons and needs.

## Components

`basics.sh` has `when::pci_vendor`, `when::usb_vendor`, `when::command`, `when::check` and `want::step`, the escape hatch for logic only one task has.\
`packages.sh` has packages, removals, locks, numbered package series, repositories and disabling repositories.\
`files.sh` has whole files from a function, root files with a validator, marked blocks inside shared files, links, folders and removals.\
`kde.sh` has KDE config keys and list items, global shortcuts, KWin window rules and panel widget settings.\
`mime.sh` has default apps, Open With order and file type handlers, with type lists read from installed apps.\
`systemd.sh` has system and user units and session environment variables.\
`github.sh` installs rpms, single files, programs from archives and whole archives from a project's newest release.\
`git.sh` follows the newest commit of a branch on any git host, and sets git's own settings.\
`apps.sh` has AppImages, autostart entries, JSON settings, gsettings and the default browser.\
`ini.sh`, `udev.sh`, `flatpak.sh` and `firewall.sh` cover those formats and services.

When one task needs something new, it goes into a component so every task gains it.

## Window

`gui/tumblegecko.py` starts engine commands with `QProcess` and passes their events to QML as signals.\
It asks for the password once, checks it with `sudo -v` and then serves it to `gui/askpass.py` on a local socket only the user can open, which sudo runs through `SUDO_ASKPASS`.\
`gui/gecko-ui/` holds the shared gecko theme, controls and password handling, copied from the gecko-ui project.\
`gui/qml/` holds the interface, an intro, the system check, one page per category, task details, review, progress and the finish.
