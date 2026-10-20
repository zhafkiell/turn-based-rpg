extends Control
## Menu utama — semua UI dibangun lewat kode.

var _menu_box: VBoxContainer
var _buttons: Array[Button] = []
var _idx := 0


func _ready() -> void:
	if GameDB.party.is_empty():
		GameDB.reset_game()
	_build_ui()
	Audio.play_menu_music()
	_update_selection()


func _build_ui() -> void:
	# Latar gradient sederhana
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "⚔  CHRONICLES OF VALOR  ⚔"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 70)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "RPG Turn-Based — Godot 4.7"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position = Vector2(0, 130)
	add_child(subtitle)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 14)
	_menu_box.set_anchors_preset(Control.PRESET_CENTER)
	_menu_box.custom_minimum_size = Vector2(320, 0)
	_menu_box.position = Vector2(-160, 40)
	add_child(_menu_box)

	var labels := ["Mulai Petualangan", "Lanjutkan (Save)", "Cara Bermain", "Keluar"]
	for lb in labels:
		var b := Button.new()
		b.text = lb
		b.custom_minimum_size = Vector2(320, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pressed.bind(b))
		b.mouse_entered.connect(_on_hover.bind(b))
		_menu_box.add_child(b)
		_buttons.append(b)


func _on_hover(b: Button) -> void:
	_set_selection(_buttons.find(b))


func _set_selection(i: int) -> void:
	_idx = clampi(i, 0, _buttons.size() - 1)
	_update_selection()


func _update_selection() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		if i == _idx:
			b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			b.text = "> " + b.text.trim_prefix("> ").trim_suffix(" <")
		else:
			b.add_theme_color_override("font_color", Color.WHITE)
			b.text = b.text.trim_prefix("> ").trim_suffix(" <")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_set_selection(_idx - 1)
		Audio.sfx_cursor()
	elif event.is_action_pressed("ui_down"):
		_set_selection(_idx + 1)
		Audio.sfx_cursor()
	elif event.is_action_pressed("ui_accept"):
		_on_pressed(_buttons[_idx])


func _on_pressed(b: Button) -> void:
	Audio.sfx_select()
	match _buttons.find(b):
		0:
			GameDB.reset_game()
			GameDB.full_rest()
			get_tree().change_scene_to_file("res://scenes/world_map.tscn")
		1:
			if GameDB.load_game():
				get_tree().change_scene_to_file("res://scenes/world_map.tscn")
			else:
				_show_message("Tidak ada save game ditemukan.")
		2:
			_show_message(
				"CARA BERMAIN:\n\n" +
				"• Gunakan panah/WASD + Enter, atau klik mouse.\n" +
				"• Jelajahi peta dunia, masuk ke titik '?' untuk bertarung.\n" +
				"• Bertempur bergiliran: Serang / Skill / Item / Pertahanan.\n" +
				"• Kalahkan semua musuh untuk menang, kumpulkan Gold & XP.\n" +
				"• Istirahat di 'K' untuk memulihkan HP/MP (bayar gold).\n" +
				"• Kalahkan Naga Bayangan di ujung peta untuk menamatkan game!"
			)
		3:
			get_tree().quit()


func _show_message(msg: String) -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 280)
	panel.position = Vector2(-280, -140)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 20
	vb.offset_right = -20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.text = "[center]" + msg + "[/center]"
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(label)

	var ok := Button.new()
	ok.text = "OK  (Enter)"
	ok.custom_minimum_size = Vector2(0, 44)
	vb.add_child(ok)
	ok.grab_focus()
	ok.pressed.connect(func(): panel.queue_free())
	await ok.pressed
	# Jika ditutup dengan cara lain, pastikan panel hilang
	panel.queue_free()
