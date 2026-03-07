extends Node

# Roguelite run state: one player vs N NPCs per wave, HP carries over.
# When MultiHustle is present we use Game.tscn + match_data with keys 1..(1+N);
# after game is ready we fix opponents and HP here.

const MAX_WAVE = 10
const WAVE_COMPLETE_DELAY = 3.0  # seconds before next wave
const PARTIAL_HEAL_PERCENT = 0.10  # +10% max HP between waves, capped at max

var is_active: bool = false
var player_char: String = ""
var current_wave: int = 0
var player_hp: int = 0
var player_max_hp: int = 0
var enemy_roster: Array = []  # shuffled list of character names (excluding player)
var main = null  # Main node (set by RogueModeMainExtension)
var hud = null  # RogueModeHUD (set by RogueModeMainExtension)
var _wave_complete_timer: Timer = null
var _next_wave_match_data: Dictionary = {}

func _ready():
	_wave_complete_timer = Timer.new()
	_wave_complete_timer.one_shot = true
	add_child(_wave_complete_timer)
	_wave_complete_timer.connect("timeout", self, "_on_wave_complete_timeout")


func start_run(p_char: String):
	player_char = p_char
	current_wave = 0
	enemy_roster = _build_enemy_roster()
	# Initial HP will be set by the first game's init; we persist after that
	player_hp = 0
	player_max_hp = 0
	is_active = true
	_start_wave()


func _build_enemy_roster() -> Array:
	var list = []
	for name in Global.name_paths:
		if name == player_char:
			continue
		list.append(name)
	# Put Bandit first if available (plan: Bandit as default enemy)
	if "Bandit" in list:
		list.erase("Bandit")
		list.insert(0, "Bandit")
	# Shuffle the rest
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(list.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var t = list[i]
		list[i] = list[j]
		list[j] = t
	return list


# Number of NPCs this wave (N). Plan: e.g. wave 1 -> 1, wave 2 -> 2, up to a cap.
func _n_for_wave() -> int:
	# Simple: wave 1 -> 1 enemy, wave 2 -> 2, ..., cap at 4
	return min(current_wave, 4)


func _start_wave():
	current_wave += 1
	if current_wave > MAX_WAVE:
		if hud:
			hud.show_banner("VICTORY!", WAVE_COMPLETE_DELAY)
		is_active = false
		return

	var n = _n_for_wave()
	var selected_characters = {1: {"name": player_char}}
	for i in range(n):
		var idx = (current_wave - 1 + i) % enemy_roster.size()
		selected_characters[2 + i] = {"name": enemy_roster[idx]}

	var data = {
		"selected_characters": selected_characters,
		"singleplayer": true,
		"p2_dummy": false,
		"stage_width": 1100,
		"seed": randi(),
		"game_length": 99999,
		"prediction_enabled": false,
		"rogue_mode": true,
		"rogue_multi_enemy": n > 1,
		"user_data": {"p1": "You"}
	}
	# Fill user_data for display names
	for i in range(n):
		data["user_data"]["p" + str(2 + i)] = selected_characters[2 + i]["name"]

	_next_wave_match_data = data
	if hud:
		hud.update_wave(current_wave, MAX_WAVE)
		hud.visible = true

	if main:
		main.match_data = data
		main.setup_game(true, data)


# Called by RogueModeMainExtension after setup_game_deferred has run and game exists.
func on_rogue_game_ready(game):
	if not is_active or not is_instance_valid(game):
		return
	# Restore / set player HP
	var p1 = game.get_player(1)
	if p1:
		if player_max_hp <= 0:
			player_max_hp = p1.hp
			player_hp = p1.hp
		else:
			p1.hp = player_hp
			p1.hp = clamp(p1.hp, 0, player_max_hp)

	# Enemy HP scaling: 50% wave 1, +5% per wave -> 95% wave 10
	var factor = 0.5 + (current_wave - 1) * 0.05
	factor = clamp(factor, 0.0, 1.0)
	if game.get("players") is Dictionary:
		for id in game.players.keys():
			if id == 1:
				continue
			var p = game.get_player(id)
			if p:
				p.hp = int(p.hp * factor)
				p.hp = max(1, p.hp)
		# Fix opponents for 1 vs N: all NPCs target player, player targets first NPC
		_fix_opponents_for_rogue(game)
	else:
		# Base game: only p2
		var p2 = game.get_player(2)
		if p2:
			p2.hp = int(p2.hp * factor)
			p2.hp = max(1, p2.hp)

	game.connect("game_won", self, "_on_game_won")


func _fix_opponents_for_rogue(game):
	if game.get("current_opponent_indicies") == null:
		return
	var ids = game.players.keys()
	game.current_opponent_indicies[1] = 2  # player targets first enemy
	for id in ids:
		if id == 1:
			continue
		game.current_opponent_indicies[id] = 1  # all NPCs target player
	for id in ids:
		var p = game.get_player(id)
		if p and game.current_opponent_indicies.has(id):
			var opp_id = game.current_opponent_indicies[id]
			p.opponent = game.get_player(opp_id)


func _on_game_won(winner):
	if not is_active:
		return
	if winner == 1:
		# Player cleared the wave
		var g = main.game if main else null
		if is_instance_valid(g):
			var p1 = g.get_player(1)
			if p1:
				player_hp = p1.hp
				player_max_hp = max(player_max_hp, p1.hp)
		# Partial heal
		player_hp = min(player_hp + int(player_max_hp * PARTIAL_HEAL_PERCENT), player_max_hp)
		if hud:
			hud.show_banner("Wave %d Complete!" % current_wave, WAVE_COMPLETE_DELAY)
		_wave_complete_timer.start(WAVE_COMPLETE_DELAY)
	else:
		# Game over
		if hud:
			hud.show_banner("GAME OVER", WAVE_COMPLETE_DELAY)
		is_active = false


func _on_wave_complete_timeout():
	if is_active and current_wave <= MAX_WAVE:
		_start_wave()
