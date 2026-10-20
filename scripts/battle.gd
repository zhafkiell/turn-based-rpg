extends Control
## Scene pertempuran turn-based.
##
## Alur: kumpulkan perintah dari hero yang aktif (urut berdasarkan SPD),
## lalu jalankan satu ronde penuh, ulangi sampai ada pihak yang menang.

enum Phase { SELECT_ACTOR, PICK_COMMAND, PICK_SKILL, PICK_ITEM, PICK_TARGET, RUNNING, DONE }

var enemies: Array[EnemyData] = []
var queue: Array = []            # antrean aksi ronde ini [{actor, action}]
var actor_index := 0             # index di queue saat eksekusi
var current_hero: PlayerData     # hero yang sedang memberi perintah
var selected_skill: Dictionary = {}
var selected_item: String = ""
var defending_set: Dictionary = {}  # hero hash -> true

# Node UI
var _enemy_nodes: Array[Dictionary] = []   # {root, hp_label, name_label, node}
var _hero_nodes: Array[Dictionary] = []
var _log: RichTextLabel
var _menu_box: VBoxContainer
var _menu_title: Label
var _prompt: Label
var _banner: Label
var _turn_label: Label


func _ready() -> void:
	_setup_encounter()
	_build_ui()
	_refresh_units()
	Audio.play_battle_music()
	_start_round()


# =========================================================
#  SETUP
# =========================================================

func _setup_encounter() -> void:
	var ids: Array = GameDB.boss_encounter if BattleBridge.is_boss \
		else GameDB.encounters[min(GameDB.current_area, GameDB.encounters.size() - 1)]
	enemies.clear()
	for eid in ids:
		var e := GameDB.make_enemy(eid)
		e.setup_for_battle()
		enemies.append(e)
	for h in GameDB.party:
		h.setup_for_battle()
	_defending_set.clear()


# =========================================================
#  PEMBANGUNAN UI
# =========================================================

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# "Lantai" arena
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.12, 0.13, 0.2)
	floor_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
	floor_rect.offset_top = 90
	floor_rect.offset_bottom = 400
	add_child(floor_rect)

	_banner = Label.new()
	_banner.text = "⚔  PERTAMPURAN!  ⚔"
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.position = Vector2(0, 24)
	add_child(_banner)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1))
	_turn_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_turn_label.position = Vector2(-260, 30)
	add_child(_turn_label)

	# Container musuh & hero dibuat oleh helper posisi
	var enemy_row := HBoxContainer.new()
	enemy_row.name = "EnemyRow"
	enemy_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_theme_constant_override("separation", 90)
	enemy_row.position = Vector2(0, 110)
	enemy_row.custom_minimum_size = Vector2(get_viewport_rect().size.x, 0)
	add_child(enemy_row)

	var hero_row := HBoxContainer.new()
	hero_row.name = "HeroRow"
	hero_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 70)
	hero_row.position = Vector2(0, 300)
	hero_row.custom_minimum_size = Vector2(get_viewport_rect().size.x, 0)
	add_child(hero_row)

	for i in enemies.size():
		_add_enemy_node(enemy_row, i)
	for i in GameDB.party.size():
		_add_hero_node(hero_row, i)

	# Log pertempuran
	var log_panel := Panel.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.position = Vector2(16, get_viewport_rect().size.y - 230)
	log_panel.custom_minimum_size = Vector2(560, 214)
	add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log.offset_left = 10
	_log.offset_top = 8
	_log.offset_right = -10
	_log.offset_bottom = -8
	_log.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(_log)

	# Menu perintah
	var menu_panel := Panel.new()
	menu_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	menu_panel.position = Vector2(get_viewport_rect().size.x - 436, get_viewport_rect().size.y - 230)
	menu_panel.custom_minimum_size = Vector2(420, 214)
	add_child(menu_panel)

	var mv := VBoxContainer.new()
	mv.set_anchors_preset(Control.PRESET_FULL_RECT)
	mv.offset_left = 14
	mv.offset_top = 10
	mv.offset_right = -14
	mv.offset_bottom = -10
	mv.add_theme_constant_override("separation", 8)
	menu_panel.add_child(mv)

	_menu_title = Label.new()
	_menu_title.add_theme_font_size_override("font_size", 18)
	_menu_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	mv.add_child(_menu_title)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	mv.add_child(_prompt)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	_menu_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(_menu_box)


func _make_unit_card(parent: Control, color: Color, size: Vector2) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = size + Vector2(0, 54)
	parent.add_child(root)

	var body := ColorRect.new()
	body.color = color
	body.size = size
	body.position = Vector2(0, 0)
	root.add_child(body)

	var name_l := Label.new()
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.position = Vector2(0, size.y + 2)
	name_l.custom_minimum_size = Vector2(size.x, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(name_l)

	var hp_l := Label.new()
	hp_l.add_theme_font_size_override("font_size", 13)
	hp_l.position = Vector2(0, size.y + 22)
	hp_l.custom_minimum_size = Vector2(size.x, 0)
	hp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hp_l)

	return {"root": root, "body": body, "name": name_l, "hp": hp_l, "base_pos": Vector2.ZERO}


func _add_enemy_node(parent: Control, idx: int) -> void:
	var e: EnemyData = enemies[idx]
	var card := _make_unit_card(parent, e.color, Vector2(90, 90))
	card["index"] = idx
	card["is_enemy"] = true
	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.modulate.a = 0.0
	click.pressed.connect(_on_unit_clicked.bind(true, idx))
	card["root"].add_child(click)
	_enemy_nodes.append(card)


func _add_hero_node(parent: Control, idx: int) -> void:
	var h: PlayerData = GameDB.party[idx]
	var card := _make_unit_card(parent, h.color, Vector2(80, 80))
	card["index"] = idx
	card["is_enemy"] = false
	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.modulate.a = 0.0
	click.pressed.connect(_on_unit_clicked.bind(false, idx))
	card["root"].add_child(click)
	_hero_nodes.append(card)


# =========================================================
#  REFRESH TAMPILAN
# =========================================================

func _refresh_units() -> void:
	for i in enemies.size():
		var c := _enemy_nodes[i]
		var e: EnemyData = enemies[i]
		c["name"].text = "%s" % e.display_name
		c["hp"].text = "HP %d/%d" % [e.hp, e.max_hp]
		c["hp"].add_theme_color_override("font_color",
			Color(0.4, 1, 0.4) if e.hp > e.max_hp * 0.5 else Color(1, 0.4, 0.4))
		c["root"].modulate.a = 1.0 if e.alive else 0.25
	for i in GameDB.party.size():
		var c := _hero_nodes[i]
		var h: PlayerData = GameDB.party[i]
		c["name"].text = "%s Lv%d" % [h.display_name, h.level]
		c["hp"].text = "HP %d/%d MP %d/%d" % [h.hp, h.max_hp, h.mp, h.max_mp]
		c["hp"].add_theme_color_override("font_color",
			Color(0.4, 1, 0.4) if h.hp > h.max_hp * 0.5 else Color(1, 0.4, 0.4))
		c["root"].modulate.a = 1.0 if h.alive else 0.25


# =========================================================
#  ALUR TURN
# =========================================================

func _start_round() -> void:
	if _check_end():
		return
	_defending_set.clear()
	queue.clear()
	for h in GameDB.party:
		if h.alive:
			queue.append({"actor": h, "kind": "hero", "action": null})
	for e in enemies:
		if e.alive:
			queue.append({"actor": e, "kind": "enemy", "action": null})
	queue.sort_custom(func(a, b): return a.actor.speed > b.actor.speed)
	actor_index = 0
	_turn_label.text = "Ronde baru dimulai!"
	_next_step()


func _next_step() -> void:
	if _check_end():
		return
	if actor_index >= queue.size():
		await get_tree().create_timer(0.5).timeout
		_start_round()
		return
	var entry: Dictionary = queue[actor_index]
	if entry.kind == "hero":
		current_hero = entry.actor
		if not current_hero.alive:
			actor_index += 1
			_next_step()
			return
		_begin_hero_command(entry)
	else:
		await _enemy_turn(entry.actor)
		actor_index += 1
		_next_step()


func _begin_hero_command(entry: Dictionary) -> void:
	_clear_menu()
	_menu_title.text = "Gilirannya: %s  (HP %d/%d, MP %d/%d)" % [
		current_hero.display_name, current_hero.hp, current_hero.max_hp,
		current_hero.mp, current_hero.max_mp]
	_prompt.text = "Pilih aksi:"
	_add_menu_button("⚔  Serang", _cmd_attack, true)
	_add_menu_button("✨  Skill", _cmd_skill, true)
	_add_menu_button("🎒  Item", _cmd_item, true)
	_add_menu_button("🛡  Pertahanan", _cmd_defend, true)


func _cmd_attack() -> void:
	Audio.sfx_select()
	queue[actor_index]["action"] = {"type": "attack"}
	_pick_target_enemy(queue[actor_index])


func _cmd_skill() -> void:
	Audio.sfx_select()
	_clear_menu()
	_menu_title.text = "%s — Pilih skill:" % current_hero.display_name
	_prompt.text = "Skill memakai MP."
	for sk in current_hero.skills:
		var usable := current_hero.mp >= int(sk.mp_cost)
		_add_menu_button("%s  (%d MP) — %s" % [sk.name, sk.mp_cost, sk.desc],
			_choose_skill.bind(sk), usable)
	_add_menu_button("« Kembali", func(): _begin_hero_command(queue[actor_index]), true)


func _choose_skill(sk: Dictionary) -> void:
	Audio.sfx_select()
	selected_skill = sk
	queue[actor_index]["action"] = {"type": "skill", "skill": sk}
	match sk.target:
		"one_enemy":
			_pick_target_enemy(queue[actor_index])
		"one_ally":
			_pick_target_ally(queue[actor_index])
		_:
			_execute_current_action()


func _cmd_item() -> void:
	Audio.sfx_select()
	_clear_menu()
	_menu_title.text = "%s — Gunakan item:" % current_hero.display_name
	_prompt.text = "Item habis? Pilih kembali."
	var any_item := false
	for item_id in GameDB.inventory:
		any_item = true
		var info: Dictionary = GameDB.items[item_id]
		var count: int = GameDB.inventory[item_id]
		_add_menu_button("%s x%d — %s" % [info.name, count, info.desc],
			_choose_item.bind(String(item_id)), true)
	if not any_item:
		_add_menu_button("(Kosong)", func(): pass, false)
	_add_menu_button("« Kembali", func(): _begin_hero_command(queue[actor_index]), true)


func _choose_item(item_id: String) -> void:
	Audio.sfx_select()
	selected_item = item_id
	queue[actor_index]["action"] = {"type": "item", "item": item_id}
	var info: Dictionary = GameDB.items[item_id]
	if info.type == "mp":
		_pick_target_ally(queue[actor_index])
	else:
		_pick_target_ally(queue[actor_index])


func _cmd_defend() -> void:
	Audio.sfx_select()
	_defending_set[current_hero.get_instance_id()] = true
	queue[actor_index]["action"] = {"type": "defend"}
	_log_line("[color=#8fd3ff]%s bersiap mempertahankan diri.[/color]" % current_hero.display_name)
	actor_index += 1
	_next_step()


# ---------- Pemilihan target ----------

var _pending_entry: Dictionary = {}

func _pick_target_enemy(entry: Dictionary) -> void:
	_pending_entry = entry
	_clear_menu()
	_menu_title.text = "%s — Pilih target musuh:" % entry.actor.display_name
	_prompt.text = "Klik musuh di arena atau pakai tombol cepat."
	var hb := HBoxContainer.new()
	_menu_box.add_child(hb)
	for i in enemies.size():
		if not enemies[i].alive:
			continue
		var b := Button.new()
		b.text = "#%d" % (i + 1)
		b.custom_minimum_size = Vector2(46, 34)
		b.pressed.connect(_select_enemy_target.bind(i))
		hb.add_child(b)
	_flash_targets(true)


func _pick_target_ally(entry: Dictionary) -> void:
	_pending_entry = entry
	_clear_menu()
	_menu_title.text = "%s — Pilih target sekutu:" % entry.actor.display_name
	_prompt.text = "Klik hero di arena atau pakai tombol cepat."
	var hb := HBoxContainer.new()
	_menu_box.add_child(hb)
	for i in GameDB.party.size():
		if not GameDB.party[i].alive:
			continue
		var b := Button.new()
		b.text = "#%d" % (i + 1)
		b.custom_minimum_size = Vector2(46, 34)
		b.pressed.connect(_select_ally_target.bind(i))
		hb.add_child(b)
	_flash_targets(false)


func _flash_targets(is_enemy: bool) -> void:
	var cards: Array = _enemy_nodes if is_enemy else _hero_nodes
	for c in cards:
		var r: Control = c["root"]
		r.pivot_offset = r.custom_minimum_size / 2.0
		var tw := create_tween()
		tw.tween_property(r, "scale", Vector2(1.08, 1.08), 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(r, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)


func _on_unit_clicked(is_enemy: bool, idx: int) -> void:
	if _pending_entry.is_empty():
		return
	if is_enemy:
		_select_enemy_target(idx)
	else:
		_select_ally_target(idx)


func _select_enemy_target(idx: int) -> void:
	if _pending_entry.is_empty():
		return
	if not enemies[idx].alive:
		return
	Audio.sfx_select()
	_flash_targets(false)
	_pending_entry["target_enemy"] = idx
	_execute_current_action()


func _select_ally_target(idx: int) -> void:
	if _pending_entry.is_empty():
		return
	if not GameDB.party[idx].alive:
		return
	Audio.sfx_select()
	_flash_targets(true)
	_pending_entry["target_ally"] = idx
	_execute_current_action()


# =========================================================
#  EKSEKUSI AKSI
# =========================================================

func _execute_current_action() -> void:
	var entry: Dictionary = queue[actor_index]
	_pending_entry = {}
	var action: Dictionary = entry.get("action", {})
	var actor = entry.actor
	match action.get("type", ""):
		"attack":
			await _do_attack(actor, entry.get("target_enemy", _first_alive_enemy()))
		"skill":
			await _do_skill(actor, action.skill, entry)
		"item":
			await _do_item(actor, action.item, entry)
		"defend":
			pass  # sudah diproses
	actor_index += 1
	await get_tree().create_timer(0.35).timeout
	_next_step()


func _first_alive_enemy() -> int:
	for i in enemies.size():
		if enemies[i].alive:
			return i
	return -1


func _first_alive_ally() -> int:
	for i in GameDB.party.size():
		if GameDB.party[i].alive:
			return i
	return -1


func _roll_damage(atk: int, power: float) -> int:
	var base := int(atk * power)
	var variance := randf_range(0.85, 1.15)
	return maxi(1, int(base * variance))


func _apply_damage_to_enemy(tint: Color, dmg: int, target_idx: int, label: String) -> void:
	if target_idx < 0 or target_idx >= enemies.size():
		return
	var e := enemies[target_idx]
	if not e.alive:
		return
	var dealt := e.take_damage(dmg)
	_log_line("%s → [color=#ffb3b3]%s kena %d![/color] (HP %d/%d)" % [label, e.display_name, dealt, e.hp, e.max_hp])
	_shake_card(_enemy_nodes[target_idx])
	_popup_number(_enemy_nodes[target_idx], "-%d" % dealt, Color(1, 0.4, 0.4))
	Audio.sfx_hit()
	if not e.alive:
		_log_line("[color=#ffd166]☠ %s kalah![/color]" % e.display_name)
	_refresh_units()


func _apply_damage_to_hero(dmg: int, target_idx: int, label: String) -> void:
	var h := GameDB.party[target_idx]
	if not h.alive:
		return
	if _defending_set.has(h.get_instance_id()):
		dmg = int(dmg * 0.5)
		label += " (tertahan separuh!)"
	var dealt := h.take_damage(dmg)
	_log_line("%s → [color=#ff8f8f]%s kena %d![/color] (HP %d/%d)" % [label, h.display_name, dealt, h.hp, h.max_hp])
	_shake_card(_hero_nodes[target_idx])
	_popup_number(_hero_nodes[target_idx], "-%d" % dealt, Color(1, 0.4, 0.4))
	Audio.sfx_hit()
	if not h.alive:
		_log_line("[color=#ff5c5c]✝ %s tumbang![/color]" % h.display_name)
	_refresh_units()


func _heal_hero(amount: int, target_idx: int, label: String) -> void:
	var h := GameDB.party[target_idx]
	var healed := h.heal(amount)
	_log_line("%s → [color=#9dffb0]%s pulih %d HP![/color]" % [label, h.display_name, healed])
	_popup_number(_hero_nodes[target_idx], "+%d" % healed, Color(0.5, 1, 0.5))
	_refresh_units()


func _do_attack(actor, target_idx: int) -> void:
	if target_idx < 0:
		return
	Audio.sfx_attack()
	var dmg := _roll_damage(actor.attack, 1.0)
	_apply_damage_to_enemy(actor.color, dmg, target_idx, "[b]%s[/b] menyerang" % actor.display_name)


func _do_skill(actor, sk: Dictionary, entry: Dictionary) -> void:
	if actor.spend_mp(int(sk.mp_cost)):
		Audio.sfx_magic()
		match sk.type:
			"damage":
				if sk.target == "all_enemies":
					for i in enemies.size():
						if enemies[i].alive:
							var dmg := _roll_damage(actor.attack, sk.power)
							_apply_damage_to_enemy(actor.color, dmg, i, "[b]%s[/b] menggunakan %s" % [actor.display_name, sk.name])
							await get_tree().create_timer(0.25).timeout
				else:
					var ti := entry.get("target_enemy", _first_alive_enemy())
					var dmg2 := _roll_damage(actor.attack, sk.power)
					_apply_damage_to_enemy(actor.color, dmg2, ti, "[b]%s[/b] menggunakan %s" % [actor.display_name, sk.name])
			"heal":
				if sk.target == "all_allies":
					for i in GameDB.party.size():
						if GameDB.party[i].alive:
							_heal_hero(int(sk.power) + actor.level * 4, i, "[b]%s[/b] merapal %s" % [actor.display_name, sk.name])
				else:
					var ai := entry.get("target_ally", _lowest_hp_ally())
					_heal_hero(int(sk.power) + actor.level * 4, ai, "[b]%s[/b] merapal %s" % [actor.display_name, sk.name])
	else:
		_log_line("[color=#aaa]%s tidak punya cukup MP![/color]" % actor.display_name)


func _lowest_hp_ally() -> int:
	var best := -1
	var lowest := 1.0
	for i in GameDB.party.size():
		var h := GameDB.party[i]
		if h.alive:
			var ratio := float(h.hp) / h.max_hp
			if best < 0 or ratio < lowest:
				lowest = ratio
				best = i
	return best


func _do_item(actor, item_id: String, entry: Dictionary) -> void:
	if not GameDB.remove_item(item_id):
		_log_line("[color=#aaa]Item habis![/color]")
		return
	var info: Dictionary = GameDB.items[item_id]
	Audio.sfx_heal()
	match info.type:
		"heal":
			var ti := entry.get("target_ally", _current_hero_index())
			_heal_hero(int(info.power), ti, "[b]%s[/b] memakai %s" % [actor.display_name, info.name])
		"mp":
			var hi := entry.get("target_ally", _current_hero_index())
			var h := GameDB.party[hi]
			h.mp = clampi(h.mp + int(info.power), 0, h.max_mp)
			_log_line("[b]%s[/b] memakai %s → MP pulih." % [actor.display_name, info.name])
			_popup_number(_hero_nodes[hi], "+MP", Color(0.5, 0.7, 1))
			_refresh_units()


func _current_hero_index() -> int:
	for i in GameDB.party.size():
		if GameDB.party[i] == current_hero:
			return i
	return _lowest_hp_ally()


# ---------- Giliran musuh (AI) ----------

func _enemy_turn(e: EnemyData) -> void:
	await get_tree().create_timer(0.4).timeout
	if not e.alive:
		return
	# AI: shaman menyembuhkan diri/sekutu saat HP rendah
	if e.special == &"skill_heal" and e.hp < e.max_hp * 0.4 and randf() < 0.6:
		var healed := e.hp
		e.hp = mini(e.max_hp, e.hp + 25)
		_log_line("[color=#ffd166]%s merapal penyembuhan (+%d HP)[/color]" % [e.display_name, e.hp - healed])
		_refresh_units()
		return
	# Serangan khusus boss/golem kadang muncul
	if e.special == &"skill_special" and randf() < 0.35:
		Audio.sfx_magic()
		_log_line("[color=#ff9d5c]💥 %s melancarkan serangan dahsyat![/color]" % e.display_name)
		for i in GameDB.party.size():
			if GameDB.party[i].alive:
				var dmg := _roll_damage(int(e.attack * 0.8), 1.0)
				_apply_damage_to_hero(dmg, i, "[b]%s[/b] menghantam" % e.display_name)
				await get_tree().create_timer(0.2).timeout
		return
	# Serangan biasa ke hero acak
	var alive_indices := []
	for i in GameDB.party.size():
		if GameDB.party[i].alive:
			alive_indices.append(i)
	if alive_indices.is_empty():
		return
	var ti: int = alive_indices[randi() % alive_indices.size()]
	Audio.sfx_attack()
	var dmg2 := _roll_damage(e.attack, 1.0)
	_apply_damage_to_hero(dmg2, ti, "[b]%s[/b] menyerang" % e.display_name)


# =========================================================
#  EFEK VISUAL
# =========================================================

func _shake_card(card: Dictionary) -> void:
	var r: Control = card["root"]
	r.pivot_offset = r.custom_minimum_size / 2.0
	var tw := create_tween()
	tw.tween_property(r, "position", r.position + Vector2(8, -6), 0.05)
	tw.tween_property(r, "position", r.position + Vector2(-8, 6), 0.05)
	tw.tween_property(r, "position", Vector2.ZERO, 0.05)


func _popup_number(card: Dictionary, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	card["root"].add_child(l)
	l.position = Vector2(card["root"].custom_minimum_size.x / 2 - 20, -10)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


func _log_line(t: String) -> void:
	_log.append_text(t + "\n")


# =========================================================
#  MENU BANTU
# =========================================================

func _clear_menu() -> void:
	for c in _menu_box.get_children():
		c.queue_free()


func _add_menu_button(text: String, cb: Callable, enabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	_menu_box.add_child(b)


# =========================================================
#  KONDISI MENANG/KALAH
# =========================================================

func _check_end() -> bool:
	if _battle_over:
		return true
	var enemies_left := false
	for e in enemies:
		if e.alive:
			enemies_left = true
			break
	var heroes_left := false
	for h in GameDB.party:
		if h.alive:
			heroes_left = true
			break
	if not enemies_left:
		_victory()
		return true
	if not heroes_left:
		_defeat()
		return true
	return false


func _victory() -> void:
	Audio.stop_music()
	Audio.sfx_victory()
	_banner.text = "🏆  KEMENANGAN!  🏆"
	_banner.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	_clear_menu()
	_menu_title.text = "Hasil pertempuran:"

	var total_xp := 0
	var total_gold := 0
	for e in enemies:
		total_xp += e.xp_reward
		total_gold += e.gold_reward
	GameDB.gold += total_gold

	var levelups := []
	for h in GameDB.party:
		if h.gain_xp(total_xp):
			levelups.append(h.display_name)

	# Progres area
	if not BattleBridge.is_boss:
		GameDB.current_area = mini(GameDB.current_area + 1, GameDB.encounters.size() - 1)
		if BattleBridge.defeated_callback.is_valid():
			BattleBridge.defeated_callback.call(BattleBridge.node_key)
	else:
		GameDB.boss_defeated = true
		# Hadiah item
	GameDB.add_item("potion", 2)

	_prompt.text = "XP +%d • Gold +%d%s" % [total_xp, total_gold,
		("\nNaik level: " + ", ".join(levelups)) if not levelups.is_empty() else ""]

	if BattleBridge.is_boss and GameDB.boss_defeated:
		_add_menu_button("🎉 TAMAT — Kembali ke Kota", _return_to_map, true)
	else:
		_add_menu_button("Lanjutkan Petualangan", _return_to_map, true)
	_finish()


func _defeat() -> void:
	Audio.stop_music()
	Audio.sfx_defeat()
	_banner.text = "💀  KEKALAHAN...  💀"
	_banner.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_clear_menu()
	_menu_title.text = "Party-mu tumbang..."
	_prompt.text = "Kamu terbangun di penginapan. Sebagian gold hilang,\ntetapi kamu hidup kembali."
	GameDB.gold = int(GameDB.gold * 0.5)
	GameDB.full_rest()
	_add_menu_button("Bangkit & Kembali ke Peta", _return_to_map, true)
	_finish()


func _return_to_map() -> void:
	BattleBridge.clear_callback()
	GameDB.save_game()
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")


func _finish() -> void:
	actor_index = 0
	queue.clear()
	_battle_over = true


var _battle_over := false
