extends Node

# Dependency check: only install if script and its base (MultiHustle main) exist.
func _can_install_extension(script_path: String) -> bool:
	var script = ResourceLoader.load(script_path)
	if script == null:
		return false
	return script.get_base_script() != null


func _init(modLoader = ModLoader):
	# modLoader.installScriptExtension("res://_AIOpponents/ModOptions.gd")
	# modLoader.installScriptExtension("res://_AIOpponents/AILoader.gd")
	# Rogue Mode requires MultiHustle: only install extension that extends MultiHustle's main.
	var rogue_ext = "res://_YOMI_Rogue/rogue_mode/RogueModeMainExtensionMultiHustle.gd"
	if _can_install_extension(rogue_ext):
		modLoader.installScriptExtension(rogue_ext)
	else:
		print("YOMI_Rogue: Rogue Mode disabled — MultiHustle is required but not found.")

func _ready():
	pass
