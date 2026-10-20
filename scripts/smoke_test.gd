extends Node
## Headless smoke-test: memuat semua scene dan menjalankan simulasi battle.

func _ready() -> void:
	print("=== SMOKE TEST START ===")
	GameDB.reset_game()

	# 1) Muat scene menu
	var menu := load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	print("MainMenu OK, buttons: ", menu.get_children().size())
	menu.queue_free()
	await get_tree().process_frame

	# 2) Muat peta dunia
	var map := load("res://scenes/world_map.tscn").instantiate()
	get_tree().root.add_child(map)
	await get_tree().process_frame
	print("WorldMap OK, tiles node: ", map.get_node_or_null("Tiles") != null)

	# 3) Muat battle reguler
	BattleBridge.setup(false, 111)
	var battle := load("res://scenes/battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	print("Battle OK, enemies: ", battle.enemies.size(), " party: ", GameDB.party.size())

	# 4) Simulasi: hero menyerang sampai menang/kalah (maks 60 aksi)
	var guard := 0
	while not battle._battle_over and guard < 60:
		guard += 1
		if battle.actor_index >= battle.queue.size():
			break
		var entry: Dictionary = battle.queue[battle.actor_index]
		if entry.kind == "hero":
			battle.current_hero = entry.actor
			entry["action"] = {"type": "attack"}
			battle._pending_entry = entry
			battle._select_enemy_target(battle._first_alive_enemy())
		await get_tree().process_frame
		await get_tree().create_timer(0.05).timeout
	print("Simulasi selesai setelah", guard, "aksi. Battle over:", battle._battle_over)

	# 5) Simpan & muat
	GameDB.save_game()
	var ok := GameDB.load_game()
	print("Save/Load OK:", ok, " gold=", GameDB.gold, " area=", GameDB.current_area)

	map.queue_free()
	battle.queue_free()
	await get_tree().process_frame
	print("=== SMOKE TEST PASS ===")
	get_tree().quit()
