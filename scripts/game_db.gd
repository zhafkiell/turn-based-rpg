extends Node
## Autoload "GameDB" — pusat data karakter, musuh, item, dan state global party.

const SAVE_PATH := "user://save.json"

# ---- Definisi skill ----
var skills: Dictionary = {
	"power_strike": {
		"name": "Tebasan Kuat", "mp_cost": 5, "type": "damage",
		"power": 1.8, "target": "one_enemy", "desc": "Serangan fisik 180% ATK"
	},
	"heavy_slash": {
		"name": "Babat Beruntun", "mp_cost": 10, "type": "damage",
		"power": 1.1, "target": "all_enemies", "desc": "Serangan ke semua musuh 110% ATK"
	},
	"fireball": {
		"name": "Bola Api", "mp_cost": 8, "type": "damage",
		"power": 2.0, "target": "one_enemy", "desc": "Sihir api 200% ATK"
	},
	"heal": {
		"name": "Healing", "mp_cost": 6, "type": "heal",
		"power": 30, "target": "one_ally", "desc": "Pulihkan 30+HP seorang allies"
	},
	"group_heal": {
		"name": "Berkah Cahaya", "mp_cost": 14, "type": "heal",
		"power": 20, "target": "all_allies", "desc": "Pulihkan HP seluruh party"
	},
}

# ---- Definisi item (untuk inventaris) ----
var items: Dictionary = {
	"potion": {"name": "Potion", "type": "heal", "power": 40, "desc": "Pulihkan 40 HP"},
	"ether": {"name": "Ether", "type": "mp", "power": 20, "desc": "Pulihkan 20 MP"},
}

# ---- Template hero ----
func make_heroes() -> Array[PlayerData]:
	var arin := PlayerData.new()
	arin.id = &"arin"
	arin.display_name = "Arin"
	arin.role = "Ksatria"
	arin.color = Color(0.85, 0.35, 0.3)
	arin.max_hp = 120
	arin.max_mp = 20
	arin.attack = 14
	arin.defense = 10
	arin.speed = 8
	arin.skills = [skills["power_strike"], skills["heavy_slash"]]

	var luna := PlayerData.new()
	luna.id = &"luna"
	luna.display_name = "Luna"
	luna.role = "Penyihir"
	luna.color = Color(0.45, 0.5, 0.95)
	luna.max_hp = 80
	luna.max_mp = 50
	luna.attack = 16
	luna.defense = 6
	luna.speed = 11
	luna.skills = [skills["fireball"], skills["group_heal"]]

	var garr := PlayerData.new()
	garr.id = &"garr"
	garr.display_name = "Garr"
	garr.role = "Ranger"
	garr.color = Color(0.35, 0.75, 0.45)
	garr.max_hp = 95
	garr.max_mp = 30
	garr.attack = 12
	garr.defense = 7
	garr.speed = 14
	garr.skills = [skills["power_strike"], skills["heal"]]

	return [arin, luna, garr]

# ---- Template musuh ----
func make_enemy(id_key: StringName) -> EnemyData:
	var e := EnemyData.new()
	match id_key:
		&"slime":
			e.id = &"slime"; e.display_name = "Slime Hijau"
			e.color = Color(0.4, 0.8, 0.4)
			e.max_hp = 45; e.attack = 9; e.defense = 3; e.speed = 5
			e.xp_reward = 18; e.gold_reward = 10
		&"bat":
			e.id = &"bat"; e.display_name = "Kelelawar Gua"
			e.color = Color(0.6, 0.4, 0.7)
			e.max_hp = 32; e.attack = 11; e.defense = 2; e.speed = 13
			e.xp_reward = 16; e.gold_reward = 8
		&"wolf":
			e.id = &"wolf"; e.display_name = "Serigala Kelabu"
			e.color = Color(0.65, 0.65, 0.7)
			e.max_hp = 60; e.attack = 13; e.defense = 5; e.speed = 10
			e.xp_reward = 25; e.gold_reward = 15
		&"shaman":
			e.id = &"shaman"; e.display_name = "Shaman Gelap"
			e.color = Color(0.9, 0.75, 0.3)
			e.max_hp = 70; e.attack = 14; e.defense = 6; e.speed = 9
			e.xp_reward = 40; e.gold_reward = 30
			e.special = &"skill_heal"
		&"golem":
			e.id = &"golem"; e.display_name = "Golem Batu"
			e.color = Color(0.55, 0.5, 0.45)
			e.max_hp = 140; e.attack = 17; e.defense = 12; e.speed = 3
			e.xp_reward = 70; e.gold_reward = 60
			e.special = &"skill_special"
		&"dragon":
			e.id = &"dragon"; e.display_name = "Naga Bayangan"
			e.color = Color(0.8, 0.2, 0.25)
			e.max_hp = 320; e.attack = 24; e.defense = 14; e.speed = 12
			e.xp_reward = 250; e.gold_reward = 200
			e.special = &"skill_special"
		_:
			e.display_name = "Musuh"
			e.max_hp = 30
	return e

# ---- Daftar encounter bertingkat (dipakai peta dunia) ----
var encounters: Array[Array] = [
	[&"slime", &"slime"],
	[&"bat", &"wolf"],
	[&"wolf", &"slime", &"bat"],
	[&"shaman", &"wolf"],
	[&"golem", &"bat", &"bat"],
	[&"shaman", &"golem"],
]
var boss_encounter: Array[StringName] = [&"dragon"]

# ---- State global ----
var party: Array[PlayerData] = []
var gold: int = 0
var inventory: Dictionary = {"potion": 5, "ether": 2}
var current_area: int = 0        # progres area di peta dunia
var boss_defeated: bool = false


func reset_game() -> void:
	party = make_heroes()
	gold = 50
	inventory = {"potion": 5, "ether": 2}
	current_area = 0
	boss_defeated = false


func full_rest() -> void:
	for h in party:
		h.hp = h.max_hp
		h.mp = h.max_mp


func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + count


func remove_item(item_id: String, count: int = 1) -> bool:
	if inventory.get(item_id, 0) < count:
		return false
	inventory[item_id] -= count
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true


func save_game() -> void:
	var heroes := []
	for h in party:
		heroes.append({
			"id": String(h.id), "level": h.level, "xp": h.xp,
			"max_hp": h.max_hp, "max_mp": h.max_mp,
			"attack": h.attack, "defense": h.defense, "speed": h.speed,
		})
	var data := {
		"gold": gold, "inventory": inventory,
		"current_area": current_area, "boss_defeated": boss_defeated,
		"heroes": heroes,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	reset_game()
	gold = int(parsed.get("gold", 0))
	current_area = int(parsed.get("current_area", 0))
	boss_defeated = bool(parsed.get("boss_defeated", false))
	var inv = parsed.get("inventory", {})
	if typeof(inv) == TYPE_DICTIONARY:
		inventory = inv
	var heroes = parsed.get("heroes", [])
	if typeof(heroes) == TYPE_ARRAY and heroes.size() > 0:
		var base := make_heroes()
		var by_id := {}
		for h in base:
			by_id[String(h.id)] = h
		party.clear()
		for hd in heroes:
			var h: PlayerData = by_id.get(String(hd.get("id", "")))
			if h:
				h.level = int(hd.get("level", 1))
				h.xp = int(hd.get("xp", 0))
				h.max_hp = int(hd.get("max_hp", h.max_hp))
				h.max_mp = int(hd.get("max_mp", h.max_mp))
				h.attack = int(hd.get("attack", h.attack))
				h.defense = int(hd.get("defense", h.defense))
				h.speed = int(hd.get("speed", h.speed))
				party.append(h)
		if party.is_empty():
			reset_game()
	full_rest()
	return true
