class_name PlayerData
extends Resource
## Data seorang karakter pemain (hero) dalam party.

@export var id: StringName = &""
@export var display_name: String = "Hero"
@export var role: String = "Petarung"
@export var color: Color = Color.WHITE

# Stat dasar
@export var max_hp: int = 100
@export var max_mp: int = 30
@export var attack: int = 12
@export var defense: int = 8
@export var speed: int = 10

# Skill yang dimiliki
@export var skills: Array[Dictionary] = []

# Status runtime (diisi saat battle dimulai)
var hp: int = 0
var mp: int = 0
var alive: bool = true
var level: int = 1
var xp: int = 0


func setup_for_battle() -> void:
	hp = max_hp
	mp = max_mp
	alive = true


func is_dead() -> bool:
	return hp <= 0


func take_damage(amount: int) -> int:
	amount = max(1, amount - int(defense * 0.5))
	hp = clampi(hp - amount, 0, max_hp)
	if hp <= 0:
		alive = false
	return amount


func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 0, max_hp)
	return hp - before


func spend_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	return true


func gain_xp(amount: int) -> bool:
	xp += amount
	var leveled := false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		leveled = true
		max_hp += 12
		max_mp += 4
		attack += 2
		defense += 2
		speed += 1
		hp = mini(hp + 12, max_hp)
		mp = mini(mp + 4, max_mp)
	return leveled


func xp_to_next() -> int:
	return 40 + level * 25
