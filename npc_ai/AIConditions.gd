# AIConditions — factory methods that return bound FuncRefs usable as transition
# conditions in NPCAIStateMachine and NPCAIPriorityAI.
#
# Usage:
#   state.add_transition(AIConditions.new().close_to(160.0), "Pressure")
#
# Each method returns a FuncRef pointing to a bound inner method, so the
# returned value can be called as: condition.call_func(ctx) -> bool.
# Because GDScript 3 doesn't have closures, conditions that need a parameter
# are implemented via a helper object that stores the threshold.

extends Reference
class_name AIConditions


# ── Parameterised condition helpers ──────────────────────────────────────────

class ThresholdCond extends Reference:
	var threshold: float
	var fn_name:   String
	var _obj

	func _init(obj, name: String, t: float):
		_obj      = obj
		fn_name   = name
		threshold = t

	func call_func(ctx) -> bool:
		return _obj.call(fn_name, ctx, threshold)


class StringCond extends Reference:
	var value: String
	var fn_name: String
	var _obj

	func _init(obj, name: String, v: String):
		_obj    = obj
		fn_name = name
		value   = v

	func call_func(ctx) -> bool:
		return _obj.call(fn_name, ctx, value)


class SimpleCond extends Reference:
	var fn_name: String
	var _obj

	func _init(obj, name: String):
		_obj    = obj
		fn_name = name

	func call_func(ctx) -> bool:
		return _obj.call(fn_name, ctx)


# ── Public factory methods ────────────────────────────────────────────────────

func close_to(dist: float):
	return ThresholdCond.new(self, "_eval_close_to", dist)

func far_from(dist: float):
	return ThresholdCond.new(self, "_eval_far_from", dist)

func my_hp_below(pct: float):
	return ThresholdCond.new(self, "_eval_my_hp_below", pct)

func opp_hp_below(pct: float):
	return ThresholdCond.new(self, "_eval_opp_hp_below", pct)

func being_comboed():
	return SimpleCond.new(self, "_eval_being_comboed")

func have_burst():
	return SimpleCond.new(self, "_eval_have_burst")

func move_available(action_name: String):
	return StringCond.new(self, "_eval_move_available", action_name)

func always():
	return SimpleCond.new(self, "_eval_always")

func i_am_airborne():
	return SimpleCond.new(self, "_eval_i_am_airborne")

func opp_is_airborne():
	return SimpleCond.new(self, "_eval_opp_is_airborne")

func is_cornered():
	return SimpleCond.new(self, "_eval_is_cornered")


# ── Evaluation methods (called via .call()) ───────────────────────────────────

func _eval_close_to(ctx, threshold: float) -> bool:
	return ctx.distance <= threshold

func _eval_far_from(ctx, threshold: float) -> bool:
	return ctx.distance >= threshold

func _eval_my_hp_below(ctx, pct: float) -> bool:
	return ctx.my_hp_pct <= pct

func _eval_opp_hp_below(ctx, pct: float) -> bool:
	return ctx.opp_hp_pct <= pct

func _eval_being_comboed(ctx) -> bool:
	return ctx.i_am_in_combo

func _eval_have_burst(ctx) -> bool:
	return ctx.my_bursts > 0

func _eval_move_available(ctx, action_name: String) -> bool:
	return ctx.has_move(action_name)

func _eval_always(_ctx) -> bool:
	return true

func _eval_i_am_airborne(ctx) -> bool:
	return ctx.i_am_airborne()

func _eval_opp_is_airborne(ctx) -> bool:
	return ctx.opp_is_airborne()

func _eval_is_cornered(ctx) -> bool:
	return ctx.is_cornered()
