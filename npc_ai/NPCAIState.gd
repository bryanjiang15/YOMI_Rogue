extends Reference
class_name NPCAIState

var state_name: String = "Unnamed"

# Back-reference to the owning state machine; set by NPCAIStateMachine.add_state()
var machine  # NPCAIStateMachine

# Array of { "condition": FuncRef, "target": String }
# Evaluated top-to-bottom; first true condition wins.
var transitions: Array = []


# Override in subclasses to return the move for this turn.
# Must return: {"action": String, "data": Variant}
func get_move(_ctx) -> Dictionary:
	return {"action": "Continue", "data": null}


# Called once when the state machine transitions INTO this state.
func on_enter(_ctx):
	pass


# Called once when the state machine transitions OUT OF this state.
func on_exit(_ctx):
	pass


# Walks all transitions and returns the target state name of the first one
# whose condition returns true.  Returns "" if no transition fires.
func check_transitions(ctx) -> String:
	for t in transitions:
		var fires: bool = false
		if t.condition == null:
			fires = true
		else:
			fires = t.condition.call_func(ctx)
		if fires:
			return t.target
	return ""


# Fluent helper — returns self so calls can be chained.
# condition: a FuncRef that accepts an AIContext and returns bool, or null for unconditional.
func add_transition(condition, target_name: String) -> NPCAIState:
	transitions.append({"condition": condition, "target": target_name})
	return self
