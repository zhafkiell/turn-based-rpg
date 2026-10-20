extends Node2D
## Peta dunia sederhana: karakter yang bisa digerakkan, titik battle,
## lokasi istirahat (inn), dan jalan menuju boss.

const TILE := 64
const MAP_W := 18
const MAP_H := 10

# Jenis tile
enum T { GRASS, PATH, TREE, WATER, BATTLE, INN, BOSS, GATE }

var grid: Array = []
var battle_nodes: Array[Vector2i] = []
var inn_pos := Vector2i(3, 8)
var boss_pos := Vector2i(16, 1)
var gate_pos := Vector2i(14, 5)

var player: CharacterBody2D
var _cam: Camera2D
var _hud: CanvasLayer
var _msg_label: Label
var _status_label: Label
var _defeated_battles: Dictionary = {}


func _ready() -> void:
	if GameDB.party.is_empty():
		GameDB.reset_game()
	_build_grid()
	_draw_background()
	_spawn_markers()   # pakai $Tiles, jadi harus setelah background
	_spawn_player()
	_build_hud()
	Audio.play_menu_music()
	_show_msg("Gunakan WASD / Panah untuk bergerak. Dekati '?' untuk bertarung.")


func _build_grid() -> void:
	grid.clear()
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			row.append(T.GRASS)
		grid.append(row)
	# Jalur utama zig-zag
	var path_points := [
		Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8),
		Vector2i(5, 7), Vector2i(5, 6), Vector2i(5, 5),
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5),
		Vector2i(9, 4), Vector2i(9, 3), Vector2i(9, 2),
		Vector2i(10, 2), Vector2i(11, 2), Vector2i(12, 2), Vector2i(13, 2),
		Vector2i(13, 3), Vector2i(13, 4), Vector2i(13, 5),
		Vector2i(14, 5), Vector2i(15, 5),
		Vector2i(15, 4), Vector2i(15, 3), Vector2i(15, 2), Vector2i(15, 1),
		Vector2i(16, 1),
	]
	for p in path_points:
		grid[p.y][p.x] = T.PATH
	# Pohon & air dekoratif
	var trees := [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(17,9), Vector2i(16,9), Vector2i(0,9), Vector2i(1,9), Vector2i(2,9), Vector2i(7,8), Vector2i(8,8), Vector2i(11,7), Vector2i(12,7), Vector2i(3,2), Vector2i(4,2)]
	for t in trees:
		if grid[t.y][t.x] == T.GRASS:
			grid[t.y][t.x] = T.TREE
	var water := [Vector2i(11,8), Vector2i(12,8), Vector2i(11,9), Vector2i(12,9), Vector2i(13,9)]
	for w in water:
		grid[w.y][w.x] = T.WATER
	# Titik pertempuran di sepanjang jalur
	battle_nodes.clear()
	var battles := [Vector2i(5,6), Vector2i(9,3), Vector2i(13,4)]
	for b in battles:
		grid[b.y][b.x] = T.BATTLE
		battle_nodes.append(b)
	grid[inn_pos.y][inn_pos.x] = T.INN
	grid[gate_pos.y][gate_pos.x] = T.GATE
	grid[boss_pos.y][boss_pos.x] = T.BOSS


func _draw_background() -> void:
	var root_bg := Node2D.new()
	root_bg.name = "Tiles"
	add_child(root_bg)
	for y in MAP_H:
		for x in MAP_W:
			var cell: T = grid[y][x]
			var r := ColorRect.new()
			r.position = Vector2(x * TILE, y * TILE)
			r.size = Vector2(TILE, TILE)
			match cell:
				T.GRASS:
					r.color = Color(0.18, 0.34, 0.2) if (x + y) % 2 == 0 else Color(0.2, 0.37, 0.22)
				T.PATH:
					r.color = Color(0.55, 0.47, 0.33)
				T.TREE:
					r.color = Color(0.1, 0.22, 0.13)
				T.WATER:
					r.color = Color(0.2, 0.35, 0.6)
				T.BATTLE:
					r.color = Color(0.5, 0.25, 0.22)
				T.INN:
					r.color = Color(0.45, 0.35, 0.6)
				T.GATE:
					r.color = Color(0.5, 0.45, 0.2)
				T.BOSS:
					r.color = Color(0.35, 0.1, 0.12)
			root_bg.add_child(r)
	# Ikon teks di tile khusus
	_add_marker(inn_pos, "🏠", Color(1, 0.9, 0.6))
	_add_marker(gate_pos, "⛩", Color(1, 0.95, 0.5))
	_add_marker(boss_pos, "☠", Color(1, 0.4, 0.4))


func _add_marker(pos: Vector2i, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(pos.x * TILE + 12, pos.y * TILE + 8)
	$Tiles.add_child(l)


func _spawn_markers() -> void:
	for b in battle_nodes:
		if _defeated_battles.get(_node_key(b), false):
			continue
		_add_marker(b, "?", Color(1, 0.85, 0.3))


func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE - 16, TILE - 16)
	shape.shape = rect
	player.add_child(shape)

	var body := ColorRect.new()
	body.color = Color(0.95, 0.8, 0.3)
	body.size = Vector2(TILE - 20, TILE - 20)
	body.position = Vector2(10, 10)
	player.add_child(body)

	var start := Vector2i(1, 8)
	player.position = Vector2(start.x * TILE, start.y * TILE) + Vector2(TILE, TILE) / 2.0
	add_child(player)

	_cam = Camera2D.new()
	_cam.enabled = true
	player.add_child(_cam)
	_cam.make_current()


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(360, 130)
	_hud.add_child(panel)

	_status_label = Label.new()
	_status_label.position = Vector2(14, 12)
	_status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_status_label)

	_msg_label = Label.new()
	_msg_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_msg_label.position = Vector2(14, get_viewport_rect().size.y - 90)
	_msg_label.custom_minimum_size = Vector2(700, 60)
	_msg_label.add_theme_font_size_override("font_size", 18)
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_hud.add_child(_msg_label)

	_update_status()


func _update_status() -> void:
	var lines := []
	lines.append("Gold: %d   Area: %d/%d" % [GameDB.gold, GameDB.current_area + 1, GameDB.encounters.size()])
	for h in GameDB.party:
		lines.append("%s Lv%d  HP %d/%d  MP %d/%d" % [h.display_name, h.level, h.hp, h.max_hp, h.mp, h.max_mp])
	lines.append("[S] Simpan   [L] Muat   [Esc] Menu")
	_status_label.text = "\n".join(lines)


func _show_msg(t: String) -> void:
	_msg_label.text = t


func _process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	player.velocity = dir * 220.0
	player.move_and_slide()

	if dir != Vector2.ZERO:
		_check_tile_interaction()

	if Input.is_action_just_pressed("save_game"):
		GameDB.save_game()
		_show_msg("Permainan disimpan ✔")
	if Input.is_action_just_pressed("load_game"):
		if GameDB.load_game():
			_show_msg("Permainan dimuat ✔")
			_update_status()
		else:
			_show_msg("Tidak ada save game.")
	if Input.is_action_just_pressed("ui_cancel"):
		Audio.stop_music()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _check_tile_interaction() -> void:
	var center := player.position
	var gx := int(center.x / TILE)
	var gy := int(center.y / TILE)
	if gx < 0 or gy < 0 or gx >= MAP_W or gy >= MAP_H:
		return
	var cell: T = grid[gy][gx]
	match cell:
		T.BATTLE:
			var key := _node_key(Vector2i(gx, gy))
			if _defeated_battles.get(key, false):
				return
			_start_battle(false, key)
		T.BOSS:
			if GameDB.boss_defeated:
				_show_msg("Boss sudah dikalahkan. Kamu adalah legenda! 🏆")
				return
			if GameDB.current_area < GameDB.encounters.size() - 1:
				_show_msg("Gerbang masih terkunci. Kalahkan semua titik '?' dulu!")
				return
			_start_battle(true, 0)
		T.INN:
			_try_inn()
		T.GATE:
			if GameDB.current_area >= GameDB.encounters.size() - 1:
				_show_msg("Gerbang terbuka — naga menunggu di utara ☠")
			else:
				_show_msg("Gerbar terkunci. Selesaikan pertempuran tersisa.")


func _node_key(pos: Vector2i) -> int:
	return pos.x * 1000 + pos.y


func _try_inn() -> void:
	var cost := 20
	if GameDB.gold >= cost:
		GameDB.gold -= cost
		GameDB.full_rest()
		_update_status()
		_show_msg("Kamu beristirahat dengan nyenyak. HP/MP pulih (-%d gold)." % cost)
	else:
		_show_msg("Gold tidak cukup untuk menginap (%d gold dibutuhkan)." % cost)


func _start_battle(is_boss: bool, node_key: int) -> void:
	BattleBridge.setup(is_boss, node_key)
	BattleBridge.defeated_callback = func(k: int):
		_defeated_battles[k] = true
		RedrawMarkers.call_deferred()
	Audio.stop_music()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func RedrawMarkers() -> void:
	# Bersihkan marker lama lalu gambar ulang
	for c in $Tiles.get_children():
		if c is Label and c.text == "?":
			c.queue_free()
	await get_tree().process_frame
	_spawn_markers()
	_update_status()
