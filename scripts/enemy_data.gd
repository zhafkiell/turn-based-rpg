class_name EnemyData
extends Resource
## Data satu jenis musuh.

@export var id: StringName = &""
@export var display_name: String = "Slime"
@export var color: Color = Color(0.5, 0.9, 0.5)
@export var max_hp: int = 40
@export var attack: int = 8
@export var defense: int = 3
@export var speed: int = 5
@export var xp_reward: int = 15
@export var gold_reward: int = 8
## Kemungkinan skill khusus ("skill_heal", "skill_special") — kosong jika tidak ada.
@export var special: StringName = &""

var hp: int = 0
var alive: bool = true


func setup_for_battle() -> void:
	hp = max_hp
	alive = true


func is_dead() -> bool:
	return hp <= 0


func take_damage(amount: int) -> int:
	amount = max(1, amount - int(defense * 0.5))
	hp = clampi(hp - amount, 0, max_hp)
	if hp <= 0:
		alive = false
	return amount
