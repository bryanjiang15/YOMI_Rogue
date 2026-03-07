extends Node

# Development bootstrap: run YOMI_Rogue mod when it is not in the game's mod folder.
#
# SETUP (only while developing):
# 1. Open the Main scene (res://Main.tscn).
# 2. Add a new child Node to the root (the node that has main.gd).
# 3. Name it e.g. "YOMI_RogueDevLoader".
# 4. Attach this script to that node: res://_YOMI_Rogue/YOMI_RogueDevLoader.gd
# 5. Set RUN_IN_DEV to true below.
#
# When the game runs, this node's _ready() will instantiate ModMain with ModLoader
# and add it to the ModLoader tree, so the mod runs the same as when loaded from the mod folder.
# Remove or disable (RUN_IN_DEV = false) before packaging the mod.

const RUN_IN_DEV = true


func _ready():
	if not RUN_IN_DEV:
		return
	var script = load("res://_YOMI_Rogue/ModMain.gd") as GDScript
	if script == null:
		push_error("YOMI_Rogue: Could not load ModMain.gd")
		return
	var instance = script.new(ModLoader)
	ModLoader.add_child(instance)
	print("YOMI_Rogue: Loaded via dev loader (Main scene)")
