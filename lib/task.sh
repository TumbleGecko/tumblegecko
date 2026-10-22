# lib/task.sh, the runtime a task's declarations run inside
#
# A task's task() function only declares what it wants through want:: components
# The same declarations describe the task, check it and apply it, so the three can never disagree

# describe, check or apply
TASK_MODE="${TASK_MODE:-check}"
TASK_ID="${TASK_ID:-}"

TASK_REQUIREMENT_COUNT=0
TASK_CHANGED=0
TASK_FAILED=0
TASK_UNKNOWN=0
TASK_NEEDED=0
TASK_NOT_APPLICABLE=0
TASK_NOT_APPLICABLE_REASON=""
TASK_NEXT_TEXT=""


# Give the next requirement a friendlier description than its component writes
say() {
	TASK_NEXT_TEXT="$*"
}

task::_should_skip() {
	(( TASK_FAILED || TASK_NOT_APPLICABLE ))
}

# Run one requirement in the current mode
# The check returns 0 when satisfied, CORE_EXIT_UNKNOWN when it cannot tell and anything else when work is needed
task::requirement() {
	local text="$1" needs="$2" check_function="$3" apply_function="$4"
	shift 4
	local index="${TASK_REQUIREMENT_COUNT}" state check_status

	TASK_REQUIREMENT_COUNT=$((TASK_REQUIREMENT_COUNT + 1))
	if [[ -n "${TASK_NEXT_TEXT}" ]]; then
		text="${TASK_NEXT_TEXT}"
		TASK_NEXT_TEXT=""
	fi

	if [[ "${TASK_MODE}" == describe ]]; then
		core::task_event requirement task="${TASK_ID}" index="${index}" text="${text}" needs="${needs}"
		return 0
	fi
	if task::_should_skip; then
		core::task_event requirement task="${TASK_ID}" index="${index}" text="${text}" state=skipped
		return 0
	fi

	"${check_function}" "$@"
	check_status=$?
	if (( check_status == CORE_EXIT_SUCCESS )); then
		state=satisfied
	elif [[ "${TASK_MODE}" == check ]]; then
		state=needed
		(( check_status == CORE_EXIT_UNKNOWN )) && state=unknown
	else
		state="$(task::_apply "${text}" "${check_function}" "${apply_function}" "$@")"
	fi

	case "${state}" in
		needed) TASK_NEEDED=1 ;;
		unknown) TASK_UNKNOWN=1 ;;
		applied) TASK_CHANGED=1 ;;
		failed) TASK_FAILED=1 ;;
	esac
	core::task_event requirement task="${TASK_ID}" index="${index}" text="${text}" needs="${needs}" state="${state}"
}

# Apply one requirement, then check it again so a step only counts once its effect is really there
task::_apply() {
	local text="$1" check_function="$2" apply_function="$3"
	shift 3
	core::info "${text}" >&2
	if ! "${apply_function}" "$@" >&2; then
		core::error "could not finish: ${text}"
		printf 'failed\n'
		return
	fi
	if ! "${check_function}" "$@" >&2; then
		core::error "finished without taking effect: ${text}"
		printf 'failed\n'
		return
	fi
	printf 'applied\n'
}

# Mark the task as not needed on this machine unless a condition holds
task::condition() {
	local text="$1" condition_function="$2"
	shift 2
	if [[ "${TASK_MODE}" == describe ]]; then
		core::task_event condition task="${TASK_ID}" text="${text}"
		return 0
	fi
	(( TASK_NOT_APPLICABLE )) && return 0
	"${condition_function}" "$@" && return 0
	TASK_NOT_APPLICABLE=1
	TASK_NOT_APPLICABLE_REASON="${text}"
}

# Ask for a restart or new login when this run changed something in the task
restart::if_changed() {
	local reason="$1"
	if [[ "${TASK_MODE}" == describe ]]; then
		core::task_event restart task="${TASK_ID}" reason="${reason}" when=changed
		return 0
	fi
	[[ "${TASK_MODE}" == apply ]] || return 0
	(( TASK_CHANGED && ! TASK_FAILED )) || return 0
	core::task_event restart task="${TASK_ID}" reason="${reason}"
}

# Run a command after this run changed something in the task, such as telling KWin to reload
# A failure here is only a warning, the change itself is already in place
on_change() {
	[[ "${TASK_MODE}" == apply ]] || return 0
	(( TASK_CHANGED && ! TASK_FAILED )) || return 0
	"$@" || core::warn "could not run: $*"
}

# Print the task's overall result as one word
task::result() {
	if (( TASK_NOT_APPLICABLE )); then
		printf 'not-applicable\n'
	elif (( TASK_FAILED )); then
		printf 'failed\n'
	elif [[ "${TASK_MODE}" == apply ]]; then
		(( TASK_CHANGED )) && printf 'changed\n' || printf 'already-done\n'
	elif (( TASK_NEEDED )); then
		printf 'needed\n'
	elif (( TASK_UNKNOWN )); then
		printf 'unknown\n'
	else
		printf 'done\n'
	fi
}
