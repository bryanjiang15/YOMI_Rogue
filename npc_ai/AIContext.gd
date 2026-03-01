extends Reference
class_name AIContext

# ── Players ───────────────────────────────────────────────────────────────────
var me          # Fighter node this AI controls
var opponent    # Fighter node opponent

# ── Positions ─────────────────────────────────────────────────────────────────
# get_pos() on Fighter returns {"x": int, "y": int} — converted here to Vector2
var my_pos:   Vector2
var opp_pos:  Vector2
var distance: float   # Euclidean distance between players

# ── Health ────────────────────────────────────────────────────────────────────
var my_hp:      float
var opp_hp:     float
var my_hp_pct:  float   # 0.0 – 1.0
var opp_hp_pct: float

# ── Combat state ──────────────────────────────────────────────────────────────
var i_am_in_combo:   bool   # opponent.combo_count > 0 means I am being juggled
var opp_is_in_combo: bool   # me.combo_count > 0 means I am juggling opponent
var my_combo_count:  int
var opp_combo_count: int

# ── Resources ─────────────────────────────────────────────────────────────────
var my_bursts:  int
var opp_bursts: int
var my_feints:  int

# ── Available moves ───────────────────────────────────────────────────────────
# Array of { "action": String, "button": ActionButton }
var available_moves: Array = []

# ── Stage constants ───────────────────────────────────────────────────────────
const STAGE_HALF_WIDTH = 1100.0
const WALL_DANGER_ZONE = 200.0

# ── Range tier constants ──────────────────────────────────────────────────────
const RANGE_MELEE    = 130.0
const RANGE_CLOSE    = 200.0
const RANGE_MIDRANGE = 320.0
const RANGE_FAR      = 480.0
const RANGE_FULL     = 700.0


func _init(player, game):
	me       = player
	opponent = player.opponent

	var my_raw  = me.get_pos()
	var opp_raw = opponent.get_pos()
	my_pos  = Vector2(my_raw.x,  my_raw.y)
	opp_pos = Vector2(opp_raw.x, opp_raw.y)
	distance = my_pos.distance_to(opp_pos)

	my_hp      = float(me.hp)
	opp_hp     = float(opponent.hp)
	my_hp_pct  = my_hp  / float(me.max_hp)      if me.max_hp      > 0 else 0.0
	opp_hp_pct = opp_hp / float(opponent.max_hp) if opponent.max_hp > 0 else 0.0

	# combo_count on the Fighter tracks how many hits the *opponent* has landed in
	# the current combo against this fighter, so opponent.combo_count > 0 means I am
	# currently being hit.
	i_am_in_combo   = opponent.combo_count > 0
	opp_is_in_combo = me.combo_count > 0
	my_combo_count  = me.combo_count
	opp_combo_count = opponent.combo_count

	my_bursts  = me.bursts_available
	opp_bursts = opponent.bursts_available
	my_feints  = me.feints

	_collect_available_moves(game)


func _collect_available_moves(game):
	available_moves = []
	var main = game.find_parent("Main")
	if main == null:
		return
	# ActionButtons node naming convention: "P1ActionButtons" for player id 1,
	# "P2ActionButtons" for player id 2. The formula mirrors AIController.gd.
	var action_buttons = main.find_node("P" + str(2 - me.id % 2) + "ActionButtons")
	if action_buttons == null:
		return
	for button in action_buttons.buttons:
		if button.is_visible():
			available_moves.append({"action": button.action_name, "button": button})


# ── Move queries ──────────────────────────────────────────────────────────────

func has_move(action_name: String) -> bool:
	for m in available_moves:
		if m.action == action_name:
			return true
	return false

# type: 0=Normal, 1=Special, 2=Super (matches state.type)
func moves_of_type(type_int: int) -> Array:
	var result = []
	for m in available_moves:
		if m.button.state and m.button.state.type == type_int:
			result.append(m)
	return result

func random_move() -> Dictionary:
	if available_moves.empty():
		return {"action": "Continue", "data": null}
	return {"action": available_moves[randi() % available_moves.size()].action, "data": null}


# ── Range convenience ─────────────────────────────────────────────────────────

func is_close(threshold: float = RANGE_CLOSE) -> bool:
	return distance <= threshold

func is_far(threshold: float = RANGE_MIDRANGE) -> bool:
	return distance >= threshold


# ── HP convenience ────────────────────────────────────────────────────────────

func i_am_low_hp(threshold_pct: float = 0.35) -> bool:
	return my_hp_pct <= threshold_pct

func opp_is_low_hp(threshold_pct: float = 0.35) -> bool:
	return opp_hp_pct <= threshold_pct


# ── Position convenience ──────────────────────────────────────────────────────

func i_am_airborne() -> bool:
	return not me.is_grounded()

func opp_is_airborne() -> bool:
	return not opponent.is_grounded()

func air_movements_left() -> int:
	return me.air_movements_left

func is_cornered(threshold: float = WALL_DANGER_ZONE) -> bool:
	return abs(my_pos.x) > (STAGE_HALF_WIDTH - threshold)

func opponent_cornered(threshold: float = WALL_DANGER_ZONE) -> bool:
	return abs(opp_pos.x) > (STAGE_HALF_WIDTH - threshold)

# Returns +1 if opponent is to the right, -1 if to the left.
func x_dir_toward_opponent() -> int:
	return 1 if opp_pos.x > my_pos.x else -1


# ── Directional data builders (for Jump / AirDash / Roll data dicts) ──────────

# Returns {"x": int, "y": int} pointing TOWARD the opponent, scaled ×100.
# y_component: fixed upward component for the result (-1.0 = straight up, 0 = horizontal)
func dir_toward_opponent(y_component: float = -0.5) -> Dictionary:
	var dx = opp_pos.x - my_pos.x
	var vec = Vector2(dx, 0.0).normalized()
	vec.y = y_component
	vec = vec.normalized()
	return {"x": int(round(vec.x * 100)), "y": int(round(vec.y * 100))}

# Returns {"x": int, "y": int} pointing AWAY from the opponent, scaled ×100.
func dir_away_from_opponent(y_component: float = 0.0) -> Dictionary:
	var dx = my_pos.x - opp_pos.x
	var vec = Vector2(dx, 0.0).normalized()
	if y_component != 0.0:
		vec.y = y_component
		vec = vec.normalized()
	return {"x": int(round(vec.x * 100)), "y": int(round(vec.y * 100))}

# Returns {"x": int, "y": int} for a jump arc.
# forward_strength: 0.0–1.0 horizontal component fraction
# toward_opponent: true = jump toward, false = jump away
# hop: true = short hop (magnitude ~0.65), false = full hop (magnitude 1.0)
func jump_data(forward_strength: float = 0.5, toward_opponent: bool = true, hop: bool = false) -> Dictionary:
	var x_sign = x_dir_toward_opponent() if toward_opponent else -x_dir_toward_opponent()
	var x_frac = clamp(forward_strength, 0.0, 1.0) * float(x_sign)
	var mag = 0.65 if hop else 1.0
	var y_frac = -sqrt(max(0.0, mag * mag - x_frac * x_frac))
	var vec = Vector2(x_frac, y_frac).normalized() * mag
	return {"x": int(round(vec.x * 100)), "y": int(round(vec.y * 100))}
