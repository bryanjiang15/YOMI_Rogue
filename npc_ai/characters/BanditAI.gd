# BanditAI — melee NPC AI for the Bandit character.
#
# Behavior:
#   Approach  — close distance toward initial-attack range (movement only)
#   Attack    — use initial attack (e.g. GroundedPunch) when in range
#   Pressure  — cycle a punch combo; fall back to any available normal attack
#   Defensive — burst out of combos; roll away when low HP
#
# State transitions:
#   Approach  → Attack     when in range for initial attack
#   Approach  → Defensive  when taken into a combo
#   Attack    → Pressure   when within melee range (160 units)
#   Pressure  → Defensive  when HP drops below 30%
#   Pressure  → Approach   when opponent escapes to mid range (250 units)
#   Defensive → Approach   when safe (not in combo, HP above 40%) OR opponent very far

extends NPCAIStateMachine

# The Bandit has a Burst move (added by Bandit.tscn) but no named punches —
# the available attack is whatever button state name Bandit exposes.
# Replace these names with the actual state names from Bandit.tscn if they differ.
const BURST_ACTION = "Burst"

const INITIAL_ATTACK = "GroundedPunch"
const INITIAL_ATTACK_RANGE = 33.0
const TOLERANCE_CLOSER = 0.65
const TOLERANCE_FURTHER_PX = 10.0

# Combo sequence — these are placeholder names; update to match actual Bandit state names.
# If a step's action isn't available the combo resets automatically (NPCAICombo behaviour).
var _pressure_combo = NPCAICombo.new(["Attack", BURST_ACTION], false)

var _planner = NPCAIMovementPlanner.new()
var _cond    = AIConditions.new()


func _ready():
	# ── Define states ─────────────────────────────────────────────────────────
	var approach  = _ApproachState.new()
	approach.state_name = "Approach"
	approach.planner    = _planner
	approach.attack_range = INITIAL_ATTACK_RANGE

	var attack = _AttackState.new()
	attack.state_name = "Attack"
	attack.initial_attack = INITIAL_ATTACK

	var pressure  = _PressureState.new()
	pressure.state_name = "Pressure"
	pressure.combo      = _pressure_combo
	pressure.planner    = _planner

	var defensive = _DefensiveState.new()
	defensive.state_name = "Defensive"
	defensive.planner    = _planner

	# ── Wire transitions ──────────────────────────────────────────────────────
	var in_attack_range_low = INITIAL_ATTACK_RANGE * TOLERANCE_CLOSER
	var in_attack_range_high = INITIAL_ATTACK_RANGE + TOLERANCE_FURTHER_PX
	approach.add_transition(_cond.in_range_between(in_attack_range_low, in_attack_range_high), "Attack")
	approach.add_transition(_cond.being_comboed(), "Defensive")

	attack.add_transition(_cond.close_to(160.0), "Pressure")

	pressure.add_transition(_cond.my_hp_below(0.30), "Defensive")
	pressure.add_transition(_cond.far_from(250.0),   "Approach")

	defensive.add_transition(_cond.always(),          "Approach") # re-eval every turn

	# ── Register (first added = initial state) ────────────────────────────────
	add_state(approach)
	add_state(attack)
	add_state(pressure)
	add_state(defensive)

	._ready()


# ── Override DI: always DI away from opponent ─────────────────────────────────
func _build_extra(ctx) -> Dictionary:
	var away = ctx.dir_away_from_opponent(0.0)
	return {"DI": away, "feint": false, "prediction": -1, "reverse": false}


# ══════════════════════════════════════════════════════════════════════════════
# Inner state classes
# Each is a lightweight NPCAIState subclass defined here to keep everything in
# one file.  For reusable states, break them out to separate .gd files.
# ══════════════════════════════════════════════════════════════════════════════

class _ApproachState extends NPCAIState:
	var planner      # NPCAIMovementPlanner
	var attack_range: float = 140.0  # target distance; transition to Attack when in range

	func get_move(ctx) -> Dictionary:
		return planner.approach_toward_range(ctx, attack_range)


class _AttackState extends NPCAIState:
	var initial_attack: String = "PalmStrike"  # override per NPC (e.g. Bandit: "GroundedPunch")

	func get_move(ctx) -> Dictionary:
		if ctx.has_move(initial_attack):
			return {"action": initial_attack, "data": null}
		return {"action": "Continue", "data": null}


class _PressureState extends NPCAIState:
	var combo    # NPCAICombo
	var planner  # NPCAIMovementPlanner

	func get_move(ctx) -> Dictionary:
		# Try to continue the combo sequence
		var m = combo.next_move(ctx)
		if m:
			return m

		# Burst if being juggled and we have one
		if ctx.i_am_in_combo and ctx.my_bursts > 0 and ctx.has_move("Burst"):
			return {"action": "Burst", "data": null}

		# Fallback: any available normal attack
		var normals = ctx.moves_of_type(0)
		if not normals.empty():
			return {"action": normals[randi() % normals.size()].action, "data": null}

		# Nothing useful — stay in place
		return {"action": "Continue", "data": null}

	func on_exit(_ctx):
		combo.reset()


class _DefensiveState extends NPCAIState:
	var planner  # NPCAIMovementPlanner

	func get_move(ctx) -> Dictionary:
		# Burst out if being comboed and resource is available
		if ctx.i_am_in_combo and ctx.my_bursts > 0 and ctx.has_move("Burst"):
			return {"action": "Burst", "data": null}

		# Roll away to create distance and gain invincibility frames
		var roll = planner.roll_away(ctx)
		if roll.action != "Continue":
			return roll

		# Back dash as secondary escape
		var backdash = planner.dash_back(ctx)
		if backdash.action != "Continue":
			return backdash

		return {"action": "Continue", "data": null}

	# Defensive → Approach transition condition (used via _cond.always() with
	# internal check): only return to Approach when genuinely safe.
	# The transition is re-evaluated every turn because we used always().
	# Override check_transitions to add the safety guard here.
	func check_transitions(ctx) -> String:
		var safe = not ctx.i_am_in_combo and ctx.my_hp_pct > 0.40
		var very_far = ctx.is_far(ctx.RANGE_FAR)
		if safe or very_far:
			return "Approach"
		return ""
