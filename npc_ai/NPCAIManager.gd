extends Node

# Map of player_id (int) → NPCAIBase instance
var controllers: Dictionary = {}

# ── Character → AI script registry ───────────────────────────────────────────
# Key:   the fighter's node name as it appears in its .tscn root node.
# Value: preloaded GDScript that extends NPCAIBase (or a subclass).
#
# Add a new entry here whenever you create a new character AI:
#   "MyCharName": preload("res://_YOMI_Rogue/npc_ai/characters/MyCharNameAI.gd")
const CHARACTER_AI_MAP = {
	"Bandit": preload("res://_YOMI_Rogue/npc_ai/characters/BanditAI.gd"),
}

# Default fallback AI script used when the character has no entry in CHARACTER_AI_MAP.
const DEFAULT_AI_SCRIPT = preload("res://_YOMI_Rogue/npc_ai/NPCAIBase.gd")


func _ready():
	var game = get_parent()

	# Never run inside a ghost simulation game
	if game.is_ghost:
		queue_free()
		return

	# player_actionable fires once per turn when all fighters need to pick their
	# next action — the same signal AIController listens to.
	game.connect("player_actionable", self, "_on_player_actionable")

	# game.players is populated during game._ready(); we connect after so that
	# by the time our _ready runs the players dictionary is already filled.
	_register_npc_players(game)


func _register_npc_players(game):
	for player in game.players.values():
		if not _should_control(player):
			continue
		var controller = _create_controller_for(player, game)
		controllers[player.id] = controller
		add_child(controller)
		print("NPCAIManager: controlling player id ", player.id,
			  " with ", controller.get_script().resource_path)


func _on_player_actionable():
	for controller in controllers.values():
		if is_instance_valid(controller):
			controller.on_player_actionable()


# ── Overridable hooks ─────────────────────────────────────────────────────────

# Returns true for any player that should be NPC-controlled.
# Default: control player id 2 (the non-human slot in singleplayer).
# Override this method in a subclass of NPCAIManager for more complex logic.
func _should_control(player) -> bool:
	return player.id == 2


func _create_controller_for(player, game) -> NPCAIBase:
	# Look up the character-specific AI by matching the fighter's node name.
	var char_name = player.get_name()
	var script = CHARACTER_AI_MAP.get(char_name, DEFAULT_AI_SCRIPT)

	var ai = NPCAIBase.new()
	ai.set_script(script)
	ai.target_player = player
	ai.game          = game
	ai.manager       = self
	return ai
