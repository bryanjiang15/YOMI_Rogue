extends CanvasLayer

# Overlay for rogue mode: wave label, player HP bar, dynamic enemy HP bars, banner.
# Visible only during a rogue run.

onready var wave_label: Label = $VBox/WaveLabel
onready var player_hp_bar: ProgressBar = $VBox/PlayerHPBar
onready var enemy_bars_container: HBoxContainer = $VBox/EnemyBarsContainer
onready var banner_label: Label = $VBox/BannerLabel
onready var banner_timer: Timer = $BannerTimer

var _enemy_bars: Array = []  # ProgressBar instances for each NPC
var _max_enemies: int = 8     # max bars to precreate

func _ready():
	visible = false
	banner_label.visible = false
	banner_timer.one_shot = true
	banner_timer.connect("timeout", self, "_on_banner_timeout")
	# Precreate enemy HP bars (simple ProgressBar)
	for i in range(_max_enemies):
		var bar = ProgressBar.new()
		bar.rect_min_size = Vector2(60, 12)
		bar.max_value = 100
		bar.value = 100
		bar.show_percentage = false
		enemy_bars_container.add_child(bar)
		_enemy_bars.append(bar)
		bar.visible = false


func update_wave(wave: int, max_wave: int):
	wave_label.text = "Wave %d / %d" % [wave, max_wave]


func update_player_hp(hp: int, max_hp: int):
	if max_hp <= 0:
		return
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = hp


func set_enemy_count(n: int):
	for i in range(_enemy_bars.size()):
		_enemy_bars[i].visible = i < n


func update_enemy_hp(index: int, hp: int, max_hp: int):
	if index < 0 or index >= _enemy_bars.size():
		return
	var bar = _enemy_bars[index]
	bar.max_value = max(1, max_hp)
	bar.value = hp
	bar.visible = true


func show_banner(text: String, duration: float = 3.0):
	banner_label.text = text
	banner_label.visible = true
	banner_timer.wait_time = duration
	banner_timer.start()


func _on_banner_timeout():
	banner_label.visible = false
