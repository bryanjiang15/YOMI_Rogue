extends Node

# Map of player_id (int) → NPCAIBase instance
var controllers: Dictionary = {}

# ── Character → AI script registry ───────────────────────────────────────────
# Key:   the fighter's node name as it appears in its .tscn root node.
# Value: path to a GDScript that extends NPCAIBase (or a subclass).
#
# Add a new entry here whenever you create a new character AI:
#   "MyCharName": "res://_YOMI_Rogue/npc_ai/characters/MyCharNameAI.gd"
const CHARACTER_AI_MAP = {
	"Bandit": "res://_YOMI_Rogue/npc_ai/characters/BanditAI.gd",
}

# Default fallback script path used when the character has no entry in CHARACTER_AI_MAP.
const DEFAULT_AI_SCRIPT_PATH = "res://_YOMI_Rogue/npc_ai/characters/BanditAI.gd"

# Whether players have been registered yet (deferred to first signal).
var _registered: bool = false

# Last game tick we notified controllers — avoid reacting twice in the same turn.
var _last_actionable_tick: int = -1


func _ready():
	var game = get_parent()

	# Never run inside a ghost simulation game
	if game.is_ghost:
		queue_free()
		return

	game.connect("player_actionable", self, "_on_player_actionable")


func _on_player_actionable():
	var game = get_parent()
	if game.current_tick == _last_actionable_tick:
		return
	_last_actionable_tick = game.current_tick

	# Lazy first-turn registration — players are ready by now.
	if not _registered:
		_register_npc_players(game)
		_registered = true

	for controller in controllers.values():
		if is_instance_valid(controller):
			controller.on_player_actionable()


func _register_npc_players(game):
	# When game has a players dict (e.g. MultiHustle or RogueGame), register for all ids != 1.
	# Otherwise standard 1v1: only id 2.
	var ids_to_check = [1, 2]
	if game.get("players") is Dictionary and game.players.size() > 0:
		ids_to_check = game.players.keys()
	for id in ids_to_check:
		var player = game.get_player(id)
		if player == null:
			continue
		if not _should_control(player, game):
			continue
		var controller = _create_controller_for(player, game)
		controllers[player.id] = controller
		add_child(controller)
		print("NPCAIManager: controlling player id ", player.id,
			  " with ", controller.get_script().resource_path)


# ── Overridable hooks ─────────────────────────────────────────────────────────

# Returns true for any player that should be NPC-controlled.
# When game has multiple players (players dict), control all ids != 1 (rogue multi-enemy).
# Otherwise control player id 2 (the non-human slot in singleplayer).
func _should_control(player, game) -> bool:
	if game.get("players") is Dictionary and game.players.size() > 1:
		return player.id != 1
	return player.id == 2


func _get_character_name(player) -> String:
	# Match the player's script file against Global.name_paths (the game's own
	# character registry).  Both the .tscn and .gd share the same base filename,
	# so "res://…/Bandit.gd" and "res://…/Bandit.tscn" both reduce to "Bandit".
	var script_base = player.get_script().resource_path.get_file().get_basename()
	for name in Global.name_paths:
		var scene_base = Global.name_paths[name].get_file().get_basename()
		if scene_base == script_base:
			return name
	# Fallback: use the raw script filename (covers modded characters not in Global)
	return script_base


func _create_controller_for(player, game):
	var char_name   = _get_character_name(player)
	var script_path = CHARACTER_AI_MAP.get(char_name, DEFAULT_AI_SCRIPT_PATH)
	var script      = load(script_path)

	var ai = NPCAIBase.new()
	if script:
		ai.set_script(script)
	ai.target_player = player
	ai.game          = game
	ai.manager       = self
	return ai
