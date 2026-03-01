extends NPCAIBase
class_name NPCAIStateMachine

# All registered states, in registration order.
var states: Array = []

# Currently active state.
var current_state: NPCAIState = null

# Optional: name of the state that should be active at start.
# If empty, the first added state is used.
var initial_state_name: String = ""


func _ready():
	if not states.empty():
		if initial_state_name != "":
			current_state = _find_state(initial_state_name)
		if current_state == null:
			current_state = states[0]


# Override of NPCAIBase.choose_move — runs transitions then delegates to state.
func choose_move(ctx) -> Dictionary:
	if current_state == null:
		return {"action": "Continue", "data": null}
	_update_state(ctx)
	return current_state.get_move(ctx)


# ── Fluent builder ────────────────────────────────────────────────────────────

func add_state(state: NPCAIState) -> NPCAIStateMachine:
	states.append(state)
	state.machine = self
	if current_state == null:
		current_state = state
	return self


# ── Internal ──────────────────────────────────────────────────────────────────

func _update_state(ctx):
	if current_state == null:
		return

	var next_name = current_state.check_transitions(ctx)
	if next_name == "" or next_name == current_state.state_name:
		return

	var next = _find_state(next_name)
	if next == null:
		push_warning("NPCAIStateMachine: transition target '" + next_name + "' not found")
		return

	current_state.on_exit(ctx)
	current_state = next
	current_state.on_enter(ctx)


func _find_state(name: String) -> NPCAIState:
	for s in states:
		if s.state_name == name:
			return s
	return null


func get_current_state_name() -> String:
	return current_state.state_name if current_state else ""
