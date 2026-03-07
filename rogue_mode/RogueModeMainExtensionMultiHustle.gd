extends "res://MultiHustle/main.gd"

# Same as RogueModeMainExtension but extends MultiHustle's main so we sit on top of their setup.
# Enables 1 vs N waves when MultiHustle is present.

var rogue_orchestrator: Node = null
var rogue_hud: Node = null
var rogue_char_picker: Control = null


func _ready():
	._ready()
	var main_menu = ui_layer.get_node_or_null("%MainMenu")
	if main_menu:
		var btn_container = main_menu.get_node_or_null("ButtonContainer")
		var singleplayer_btn = ui_layer.get_node_or_null("%SingleplayerButton")
		if btn_container and singleplayer_btn:
			var rogue_btn = Button.new()
			rogue_btn.name = "RogueModeButton"
			rogue_btn.text = "Rogue Mode"
			rogue_btn.connect("pressed", self, "_on_rogue_mode_pressed")
			btn_container.add_child(rogue_btn)
			btn_container.move_child(rogue_btn, singleplayer_btn.get_index() + 1)

	rogue_orchestrator = preload("res://_YOMI_Rogue/rogue_mode/RogueModeOrchestrator.gd").new()
	rogue_orchestrator.name = "RogueModeOrchestrator"
	rogue_orchestrator.main = self
	add_child(rogue_orchestrator)

	var hud_scene = load("res://_YOMI_Rogue/rogue_mode/RogueModeHUD.tscn") as PackedScene
	if hud_scene:
		rogue_hud = hud_scene.instance()
		rogue_hud.name = "RogueModeHUD"
		add_child(rogue_hud)
		rogue_orchestrator.hud = rogue_hud


func _on_rogue_mode_pressed():
	hide_main_menu(true)
	_build_rogue_char_picker()


func _build_rogue_char_picker():
	if rogue_char_picker and is_instance_valid(rogue_char_picker):
		rogue_char_picker.queue_free()
	rogue_char_picker = PanelContainer.new()
	rogue_char_picker.name = "RogueCharPicker"
	var vbox = VBoxContainer.new()
	var title = Label.new()
	title.text = "Select your character"
	vbox.add_child(title)
	for char_name in Global.name_paths:
		var btn = Button.new()
		btn.text = char_name
		btn.connect("pressed", self, "_on_rogue_char_picked", [char_name])
		vbox.add_child(btn)
	rogue_char_picker.add_child(vbox)
	ui_layer.add_child(rogue_char_picker)
	rogue_char_picker.rect_position = Vector2(200, 150)
	rogue_char_picker.rect_min_size = Vector2(280, 400)


func _on_rogue_char_picked(char_name: String):
	if rogue_char_picker and is_instance_valid(rogue_char_picker):
		rogue_char_picker.queue_free()
		rogue_char_picker = null
	rogue_orchestrator.start_run(char_name)


func _process(_delta):
	if not rogue_orchestrator or not rogue_orchestrator.is_active or not rogue_hud or not is_instance_valid(game):
		return
	var p1 = game.get_player(1)
	if p1:
		rogue_hud.update_player_hp(p1.hp, p1.MAX_HEALTH)
	if game.get("players") is Dictionary:
		rogue_hud.set_enemy_count(game.players.size() - 1)
		var idx = 0
		for id in game.players.keys():
			if id == 1:
				continue
			var p = game.get_player(id)
			if p:
				rogue_hud.update_enemy_hp(idx, p.hp, p.MAX_HEALTH)
			idx += 1
	else:
		var p2 = game.get_player(2)
		if p2:
			rogue_hud.set_enemy_count(1)
			rogue_hud.update_enemy_hp(0, p2.hp, p2.MAX_HEALTH)


func setup_game_deferred(singleplayer, data):
	.setup_game_deferred(singleplayer, data)
	if not data.get("rogue_mode") and not data.get("rogue_multi_enemy"):
		return
	if rogue_orchestrator and rogue_orchestrator.is_active and is_instance_valid(game):
		rogue_orchestrator.on_rogue_game_ready(game)
