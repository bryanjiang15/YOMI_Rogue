extends Reference
class_name NPCAIMovementChain

# A queue of move steps consumed one per turn.
# Each step is either:
#   { "action": String, "data": Variant }   — an explicit move
#   FuncRef (ctx) -> Dictionary             — a planner call resolved at execution time
var _steps: Array = []


# Enqueue an explicit move.
func then(action: String, data = null) -> NPCAIMovementChain:
	_steps.append({"action": action, "data": data})
	return self

# Enqueue a planner call (resolved each turn with the current ctx).
# fn must be a FuncRef that accepts one argument (AIContext) and returns a Dictionary.
func then_planner(fn) -> NPCAIMovementChain:
	_steps.append(fn)
	return self

# Returns the next move in the chain, or null if the chain is finished.
# Consumes the step only if the required action is available.
# If a step's action is unavailable the chain is aborted (game state changed).
func next_move(ctx) -> Dictionary:
	if _steps.empty():
		return null

	var step = _steps[0]

	if step is Dictionary:
		# Validate availability (skip "Continue" which is always valid)
		if step.action != "Continue" and not ctx.has_move(step.action):
			_steps.clear()
			return null
		_steps.pop_front()
		return step

	# FuncRef / bound method — resolve dynamically
	_steps.pop_front()
	return step.call_func(ctx)


func is_complete() -> bool:
	return _steps.empty()


func reset():
	_steps.clear()


func steps_remaining() -> int:
	return _steps.size()
