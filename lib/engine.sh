# lib/engine.sh, find tasks and describe, check or run them
#
# Every command prints engine events as JSON lines, which the installer window reads directly
# engine::present turns the same events into plain text for a terminal

ENGINE_COMPONENTS_DIR="${TUMBLEGECKO_LIB}/components"


# ============================================================================
# Finding tasks

# Print every task file, in run order
engine::task_files() {
	find "${TUMBLEGECKO_TASKS}" -mindepth 2 -maxdepth 2 -type f -name '*.sh' -print | sort
}

# A task's id is its category and file name without their ordering numbers, such as software/artcraft
engine::task_id() {
	local file="$1" category name
	category="$(basename "$(dirname "${file}")")"
	name="$(basename "${file}" .sh)"
	printf '%s/%s\n' "${category#[0-9]*-}" "${name#[0-9]*-}"
}

engine::task_file() {
	local wanted="$1" file
	while IFS= read -r file; do
		[[ "$(engine::task_id "${file}")" == "${wanted}" ]] && { printf '%s\n' "${file}"; return 0; }
	done < <(engine::task_files)
	return 1
}

# Print the files for the given task ids, or every task when none are given
engine::resolve_tasks() {
	local id file
	if (( $# == 0 )); then
		engine::task_files
		return 0
	fi
	for id in "$@"; do
		file="$(engine::task_file "${id}")" || {
			core::error "no task with the id ${id}"
			return 1
		}
		printf '%s\n' "${file}"
	done
}

# Print one of the header fields at the top of a task file
engine::task_field() {
	local file="$1" key="$2"
	awk -v key="${key}" '
		NR == 1 && /^#!/ { next }
		!/^#/ { exit }
		$0 ~ "^#[ \t]+" key ":" { sub("^#[ \t]+" key ":[ \t]*", ""); sub(/[ \t]+$/, ""); print; exit }
	' "${file}"
}


# ============================================================================
# Running one task

# Run a task file's declarations in one mode inside a subshell, printing its raw output stream
engine::_task_stream() {
	local file="$1" mode="$2"
	(
		TASK_MODE="${mode}"
		TASK_ID="$(engine::task_id "${file}")"
		# shellcheck source=lib/task.sh
		. "${TUMBLEGECKO_LIB}/task.sh"
		engine::_load_components
		# shellcheck source=/dev/null
		. "${file}"
		if ! declare -F task >/dev/null; then
			core::task_event result task="${TASK_ID}" mode="${mode}" result=failed \
				reason="the task file has no task() function"
			exit "${CORE_EXIT_FAILURE}"
		fi
		engine::_check_components "${file}" || exit "${CORE_EXIT_FAILURE}"
		task
		core::task_event result task="${TASK_ID}" mode="${mode}" result="$(task::result)" \
			reason="${TASK_NOT_APPLICABLE_REASON}"
	) 2>&1
}

# A misspelt or missing component would otherwise only print "command not found" and let the task carry on
engine::_check_components() {
	local file="$1" name missing=0
	while IFS= read -r name; do
		declare -F "${name}" >/dev/null && continue
		core::task_event result task="${TASK_ID}" mode="${TASK_MODE}" result=failed reason="unknown component ${name}"
		core::error "${file} uses ${name}, which no component defines"
		missing=1
	done < <(grep -oE '\b(want|when|restart)::[a-z_]+' "${file}" | sort -u)
	return "${missing}"
}

engine::_load_components() {
	local component
	for component in "${ENGINE_COMPONENTS_DIR}"/*.sh; do
		# shellcheck source=/dev/null
		. "${component}"
	done
}

# Turn a task's raw output into events, writing its log text to a file when one is given
engine::_events_from_stream() {
	local task_id="$1" log_file="$2" keep_log="$3" line
	while IFS= read -r line; do
		if [[ "${line}" == "${CORE_EVENT_MARKER}"* ]]; then
			printf '%s\n' "${line#"${CORE_EVENT_MARKER}"}"
			continue
		fi
		[[ -n "${log_file}" ]] && printf '%s\n' "${line}" >> "${log_file}"
		(( keep_log )) && core::event log task="${task_id}" line="${line}"
	done
}


# ============================================================================
# Commands

# Print the catalog of every task as one JSON array
engine::catalog() {
	local file id category
	while IFS= read -r file; do
		id="$(engine::task_id "${file}")"
		category="$(basename "$(dirname "${file}")")"
		engine::_task_stream "${file}" describe | engine::_events_from_stream "${id}" "" 0 \
			| jq -sc --arg id "${id}" --arg category "${category#[0-9]*-}" \
				--arg name "$(engine::task_field "${file}" name)" \
				--arg summary "$(engine::task_field "${file}" summary)" \
				--arg default "$(engine::task_field "${file}" default)" \
				--arg group "$(engine::task_field "${file}" group)" '
				{
					id: $id, category: $category, group: $group, name: $name, summary: $summary,
					default: ($default != "off"),
					requirements: [.[] | select(.event == "requirement") | {text, needs}],
					conditions: [.[] | select(.event == "condition") | .text],
					restarts: [.[] | select(.event == "restart") | .reason],
					needs: ([.[] | select(.event == "requirement") | .needs | split(" ")[]]
						| unique | map(select(. != "")))
				}'
	done < <(engine::task_files) | jq -sc '.'
}

# Check tasks without changing anything, printing one status event per task
# Tasks are checked side by side because most of the time goes to waiting on zypper and the network
engine::check() {
	local files file directory index=0 pids=()
	mapfile -t files < <(engine::resolve_tasks "$@") || return 1
	directory="$(mktemp -d)" || return 1
	for file in "${files[@]}"; do
		engine::_check_one "${file}" > "${directory}/${index}" &
		pids+=("$!")
		index=$((index + 1))
	done
	for index in "${!pids[@]}"; do
		wait "${pids[${index}]}"
		cat "${directory}/${index}"
	done
	rm -rf "${directory}"
}

engine::_check_one() {
	local file="$1" id
	id="$(engine::task_id "${file}")"
	engine::_task_stream "${file}" check | engine::_events_from_stream "${id}" "" 0 \
		| jq -sc --arg id "${id}" '
			{
				event: "status", task: $id,
				status: ((map(select(.event == "result")) | last | .result) // "failed"),
				reason: ((map(select(.event == "result")) | last | .reason) // ""),
				requirements: [.[] | select(.event == "requirement") | {text, needs, state}]
			}'
}

# Apply tasks in order, streaming their progress and log as events
engine::run() {
	local files file id batch_directory log_file result failed=0
	mapfile -t files < <(engine::resolve_tasks "$@") || return 1
	batch_directory="${TUMBLEGECKO_LOGS}/$(date +%Y-%m-%d_%H-%M-%S)"
	mkdir -p "${batch_directory}"
	core::event run state=start total="${#files[@]}" logs="${batch_directory}"

	for file in "${files[@]}"; do
		id="$(engine::task_id "${file}")"
		log_file="${batch_directory}/${id//\//-}.log"
		core::event task task="${id}" state=start name="$(engine::task_field "${file}" name)"
		engine::_task_stream "${file}" apply \
			| engine::_events_from_stream "${id}" "${log_file}" 1 | tee "${batch_directory}/.events"
		result="$(jq -r 'select(.event == "result") | .result' "${batch_directory}/.events")"
		[[ -n "${result}" ]] || result=failed
		[[ "${result}" == failed ]] && failed=$((failed + 1))
		core::event task task="${id}" state=end result="${result}" log="${log_file}"
	done

	rm -f "${batch_directory}/.events"
	core::event run state=end failed:="${failed}"
	(( failed == 0 ))
}


# ============================================================================
# Terminal output

# Read engine events and print them as text for a person at a terminal
engine::present() {
	jq -r --unbuffered '
		def mark: {satisfied: "ok  ", applied: "done", needed: "todo", unknown: "??  ",
			failed: "FAIL", skipped: "skip"}[.] // .;
		if .event == "status" then
			"\(.status | ascii_upcase | .[0:14])\t\(.task)" + (if .reason != "" then "  (\(.reason))" else "" end),
			(.requirements[] | select(.state != "satisfied") | "    \(.state | mark)  \(.text)")
		elif .event == "precondition" then "\(if .ok then "ok  " else "FAIL" end)  \(.name): \(.detail)"
		elif .event == "run" and .state == "start" then "Running \(.total) tasks, logs in \(.logs)"
		elif .event == "run" then "\nFinished, \(.failed) failed"
		elif .event == "task" and .state == "start" then "\n== \(.name)"
		elif .event == "task" then "   result: \(.result)"
		elif .event == "requirement" then "   \(.state | mark)  \(.text)"
		elif .event == "log" then "      \(.line)"
		elif .event == "restart" then "   restart needed: \(.reason)"
		else empty end'
}
