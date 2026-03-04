extends Reference
class_name NPCAICombo

# Ordered list of action name strings that form the combo.
var sequence: Array = []

# Whether to restart from the beginning after the last move.
var loop: bool = false

var _index: int = 0


func _init(moves: Array, should_loop: bool = false):
	sequence = moves
	loop = should_loop


# Returns the next move dict if the next action in the sequence is available
# in ctx.available_moves, or null if the combo is finished / action unavailable.
# Automatically advances the internal index on success and resets on failure.
func next_move(ctx):
	if sequence.empty():
		return null

	if _index >= sequence.size():
		if loop:
			_index = 0
		else:
			return null

	var action = sequence[_index]
	if ctx.has_move(action):
		_index += 1
		if loop and _index >= sequence.size():
			_index = 0
		return {"action": action, "data": null}
	else:
		reset()
		return null


func reset():
	_index = 0


func is_complete() -> bool:
	return not loop and _index >= sequence.size()


func current_step() -> int:
	return _index
