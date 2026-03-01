extends "res://game.gd"


func _ready():
	add_child(preload("res://_AIOpponents/AIController.tscn").instance())
	add_child(preload("res://_YOMI_Rogue/npc_ai/NPCAIManager.tscn").instance())
	._ready()

