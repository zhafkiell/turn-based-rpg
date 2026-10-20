extends Node
## Autoload "BattleBridge" — membawa data encounter antar scene.

var is_boss: bool = false
var node_key: int = 0
var defeated_callback: Callable = Callable()


func setup(boss: bool, key: int) -> void:
	is_boss = boss
	node_key = key


func clear_callback() -> void:
	defeated_callback = Callable()
