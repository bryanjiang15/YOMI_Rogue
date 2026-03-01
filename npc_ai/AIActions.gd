# AIActions — static move-selector helpers.
#
# Each method returns an object with a call_func(ctx) -> Dictionary method,
# making them usable as one-liner move selectors inside NPCAIState.get_move:
#
#   func get_move(ctx):
#       return AIActions.new().use_first_available(["Sweep","Kick","Punch"]).call_func(ctx)

extends Reference
class_name AIActions


# ── Action objects ────────────────────────────────────────────────────────────

class UseAction extends Reference:
	var action_name: String
	var data

	func _init(name: String, d = null):
		action_name = name
		data = d

	func call_func(ctx) -> Dictionary:
		if ctx.has_move(action_name):
			return {"action": action_name, "data": data}
		return {"action": "Continue", "data": null}


class UseFirstAvailableAction extends Reference:
	var names: Array

	func _init(action_names: Array):
		names = action_names

	func call_func(ctx) -> Dictionary:
		for name in names:
			if ctx.has_move(name):
				return {"action": name, "data": null}
		return {"action": "Continue", "data": null}


class RandomTypeAction extends Reference:
	var type_int: int

	func _init(t: int):
		type_int = t

	func call_func(ctx) -> Dictionary:
		var moves = ctx.moves_of_type(type_int)
		if moves.empty():
			return {"action": "Continue", "data": null}
		return {"action": moves[randi() % moves.size()].action, "data": null}


class RandomAnyAction extends Reference:
	func call_func(ctx) -> Dictionary:
		return ctx.random_move()


class ContinueAction extends Reference:
	func call_func(_ctx) -> Dictionary:
		return {"action": "Continue", "data": null}


# ── Public factories ──────────────────────────────────────────────────────────

# Use a specific named action (falls back to Continue if unavailable).
func use(action_name: String, data = null):
	return UseAction.new(action_name, data)

# Try each name in order; use the first one that's available this turn.
func use_first_available(action_names: Array):
	return UseFirstAvailableAction.new(action_names)

# Random move of type 0 (Normal attacks).
func random_normal():
	return RandomTypeAction.new(0)

# Random move of type 1 (Specials).
func random_special():
	return RandomTypeAction.new(1)

# Random move of type 2 (Supers).
func random_super():
	return RandomTypeAction.new(2)

# Random move from all available this turn.
func random_any():
	return RandomAnyAction.new()

# Always returns Continue (hold / wait).
func continue_hold():
	return ContinueAction.new()
