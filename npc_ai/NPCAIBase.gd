extends Node
class_name NPCAIBase

var target_player = null   # Fighter node this AI controls
var game          = null   # Game node (parent of NPCAIManager)
var manager       = null   # NPCAIManager back-reference

# Cached reference to the Main node (parent of Game), found once on first use.
var _main = null

# Stores the last submitted move so it can be re-applied if ActionButtons
# fires action_selected and tries to overwrite it (mirrors AIController._edit_queue).
var _last_action: String  = "Continue"
var _last_data            = null
var _last_extra: Dictionary = {}

# Whether we have already connected to target_player.action_selected.
var _player_connected: bool = false


# ── Called by NPCAIManager each turn ─────────────────────────────────────────

func on_player_actionable():
	if target_player == null or not is_instance_valid(target_player):
		return

	# Lazy-connect to action_selected once the player node is confirmed valid.
	if not _player_connected:
		target_player.connect("action_selected", self, "_on_action_selected")
		_player_connected = true

	var ctx = AIContext.new(target_player, game)
	var result = choose_move(ctx)

	# Validate: if the chosen action isn't actually available this turn, fall
	# back to Continue so the game never gets an invalid queued action.
	if result.action != "Continue" and not ctx.has_move(result.action):
		result = {"action": "Continue", "data": null}

	_apply_result(result, ctx)


# ── Override in subclasses ────────────────────────────────────────────────────

func choose_move(_ctx) -> Dictionary:
	return {"action": "Continue", "data": null}


# ── Internal ──────────────────────────────────────────────────────────────────

func _apply_result(result: Dictionary, ctx):
	_last_action = result.get("action", "Continue")
	_last_data   = result.get("data",   null)
	_last_extra  = _build_extra(ctx)

	target_player.queued_action = _last_action
	target_player.queued_data   = _last_data
	target_player.queued_extra  = _last_extra

	var main = _get_main()
	if main:
		main.call_deferred("_start_ghost")


# Re-apply the AI's choice whenever ActionButtons fires action_selected.
# This mirrors AIController._edit_queue (lines 127-130) and prevents the
# human-facing UI from overwriting the AI's decision.
func _on_action_selected(_action, _data, _extra):
	if target_player == null or not is_instance_valid(target_player):
		return
	target_player.queued_action = _last_action
	target_player.queued_data   = _last_data
	target_player.queued_extra  = _last_extra


func _build_extra(ctx) -> Dictionary:
	var away = ctx.dir_away_from_opponent(0.0)
	return {
		"DI": away,
		"feint": false,
		"prediction": -1,
		"reverse": false
	}


func _get_main():
	if _main != null and is_instance_valid(_main):
		return _main
	if game != null and is_instance_valid(game):
		_main = game.find_parent("Main")
	return _main
