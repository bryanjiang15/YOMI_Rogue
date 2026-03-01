# NPCAIMovementPlanner — stateless movement decision helper.
#
# Call static-style methods from any NPCAIState or NPCAIBase subclass:
#   return NPCAIMovementPlanner.new().approach(ctx)
#
# All methods return {"action": String, "data": Variant}.

extends Reference
class_name NPCAIMovementPlanner


# ── Approach ──────────────────────────────────────────────────────────────────

# Closes distance toward the opponent using whatever movement is available.
# Preference: DashForward > forward jump > short hop > AirDash > Run > Continue
func approach(ctx) -> Dictionary:
	if not ctx.i_am_airborne():
		# Ground dash — use a shorter distance when almost in range to avoid over-committing
		if ctx.has_move("DashForward"):
			var dash_dist = 40 if ctx.is_close(ctx.RANGE_CLOSE * 1.4) else 100
			return {"action": "DashForward", "data": {"x": dash_dist}}

		# Full forward jump to cover ground and create an aerial threat
		if ctx.has_move("Jump"):
			if ctx.distance >= ctx.RANGE_MIDRANGE:
				return {"action": "Jump", "data": ctx.jump_data(0.7, true, false)}
			# Short hop when already somewhat close
			return {"action": "Jump", "data": ctx.jump_data(0.6, true, true)}

		if ctx.has_move("Run"):
			return {"action": "Run", "data": null}
	else:
		# Airborne — use an airdash toward the opponent if budget remains
		if ctx.air_movements_left() > 0 and ctx.has_move("AirDash"):
			return _airdash_toward(ctx)

	return {"action": "Continue", "data": null}


# ── Escape ────────────────────────────────────────────────────────────────────

# Creates distance from the opponent.
# Preference: Roll back > DashBackward > back jump > AirDash away > Continue
# Special case: if cornered, jump over the opponent instead.
func escape(ctx) -> Dictionary:
	if not ctx.i_am_airborne():
		# Cornered — can't retreat further; jump over or roll through instead
		if ctx.is_cornered():
			if ctx.has_move("Jump"):
				return {"action": "Jump", "data": ctx.jump_data(0.85, true, false)}
			if ctx.has_move("Roll"):
				return _roll_toward(ctx)

		if ctx.has_move("Roll"):
			return _roll_away(ctx)

		if ctx.has_move("DashBackward"):
			return {"action": "DashBackward", "data": {"x": 100}}

		if ctx.has_move("Jump"):
			return {"action": "Jump", "data": ctx.jump_data(0.65, false, false)}
	else:
		if ctx.air_movements_left() > 0 and ctx.has_move("AirDash"):
			return _airdash_away(ctx)

	return {"action": "Continue", "data": null}


# ── Neutral (maintain preferred range) ───────────────────────────────────────

# Approach if too far, escape if too close, hold otherwise.
# A slack dead-zone prevents oscillation when already near preferred_range.
func neutral(ctx, preferred_range: float = 200.0) -> Dictionary:
	var slack = 60.0
	if ctx.distance > preferred_range + slack:
		return approach(ctx)
	if ctx.distance < preferred_range - slack:
		return escape(ctx)
	return {"action": "Continue", "data": null}


# ── Specific helpers ──────────────────────────────────────────────────────────

func jump_toward(ctx, hop: bool = false) -> Dictionary:
	if ctx.has_move("Jump"):
		return {"action": "Jump", "data": ctx.jump_data(0.7, true, hop)}
	return {"action": "Continue", "data": null}

func jump_neutral(ctx) -> Dictionary:
	if ctx.has_move("Jump"):
		return {"action": "Jump", "data": {"x": 0, "y": -100}}
	return {"action": "Continue", "data": null}

func jump_back(ctx) -> Dictionary:
	if ctx.has_move("Jump"):
		return {"action": "Jump", "data": ctx.jump_data(0.65, false, false)}
	return {"action": "Continue", "data": null}

func airdash_toward(ctx) -> Dictionary:
	if ctx.has_move("AirDash"):
		return _airdash_toward(ctx)
	return {"action": "Continue", "data": null}

func airdash_away(ctx) -> Dictionary:
	if ctx.has_move("AirDash"):
		return _airdash_away(ctx)
	return {"action": "Continue", "data": null}

func dash_in(ctx) -> Dictionary:
	if ctx.has_move("DashForward"):
		return {"action": "DashForward", "data": {"x": 100}}
	return {"action": "Continue", "data": null}

func dash_in_short(ctx) -> Dictionary:
	if ctx.has_move("DashForward"):
		return {"action": "DashForward", "data": {"x": 40}}
	return {"action": "Continue", "data": null}

func dash_back(ctx) -> Dictionary:
	if ctx.has_move("DashBackward"):
		return {"action": "DashBackward", "data": {"x": 100}}
	return {"action": "Continue", "data": null}

func roll_through(ctx) -> Dictionary:
	if ctx.has_move("Roll"):
		return _roll_toward(ctx)
	return {"action": "Continue", "data": null}

func roll_away(ctx) -> Dictionary:
	if ctx.has_move("Roll"):
		return _roll_away(ctx)
	return {"action": "Continue", "data": null}

# Handles movement while airborne based on intent string: "approach", "escape", "neutral"
func air_movement(ctx, intent: String = "approach") -> Dictionary:
	var has_air = ctx.air_movements_left() > 0
	match intent:
		"approach":
			if has_air and ctx.has_move("AirDash"):
				return _airdash_toward(ctx)
		"escape":
			if has_air and ctx.has_move("AirDash"):
				return _airdash_away(ctx)
		"neutral":
			if has_air and ctx.has_move("AirDash") and ctx.is_far(ctx.RANGE_FAR):
				return _airdash_toward(ctx)
	return {"action": "Continue", "data": null}


# ── Internal direction builders ───────────────────────────────────────────────

func _airdash_toward(ctx) -> Dictionary:
	var dx = ctx.x_dir_toward_opponent()
	return {"action": "AirDash", "data": {"x": dx * 90, "y": -30}}

func _airdash_away(ctx) -> Dictionary:
	var dx = -ctx.x_dir_toward_opponent()
	return {"action": "AirDash", "data": {"x": dx * 90, "y": -20}}

func _roll_toward(ctx) -> Dictionary:
	return {"action": "Roll", "data": {"x": ctx.x_dir_toward_opponent() * 100, "y": 0}}

func _roll_away(ctx) -> Dictionary:
	return {"action": "Roll", "data": {"x": -ctx.x_dir_toward_opponent() * 100, "y": 0}}
