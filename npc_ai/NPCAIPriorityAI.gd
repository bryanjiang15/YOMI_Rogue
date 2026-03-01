extends NPCAIBase
class_name NPCAIPriorityAI

# Array of { "action": String, "condition": FuncRef or null, "data": Variant }
# Evaluated top-to-bottom each turn; first entry whose action is available AND
# whose condition returns true (or is null) wins.
var priority_table: Array = []


# Override of NPCAIBase.choose_move
func choose_move(ctx) -> Dictionary:
	for entry in priority_table:
		# Skip if this move is not currently available in the ActionButtons
		if entry.action != "Continue" and not ctx.has_move(entry.action):
			continue
		# Check condition
		if entry.condition == null or entry.condition.call_func(ctx):
			return {"action": entry.action, "data": entry.get("data", null)}
	return {"action": "Continue", "data": null}


# Fluent builder — returns self so calls can be chained.
# condition: a FuncRef(ctx) -> bool, or null for unconditional.
# data: optional pre-set data dict for the action.
func add_priority(action: String, condition = null, data = null) -> NPCAIPriorityAI:
	priority_table.append({"action": action, "condition": condition, "data": data})
	return self
