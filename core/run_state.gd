extends RefCounted

# 仅由 game_rules 写入；界面只取得公开快照。
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var resolving: Array = []
var jokers: Array = ["big", "small"]
var spent_jokers: Array = []
var enemy_order: Array = []
var removed_enemies: Array = []
var enemy_index: int = 0
var enemy: Dictionary = {}
var defeated: int = 0
var phase: String = "not_started"
var shield: int = 0
var pending_damage: int = 0
var end_reason: String = ""


func copy() -> RefCounted:
	var snapshot = get_script().new()
	snapshot.hand = hand.duplicate(true)
	snapshot.draw_pile = draw_pile.duplicate(true)
	snapshot.discard_pile = discard_pile.duplicate(true)
	snapshot.resolving = resolving.duplicate(true)
	snapshot.jokers = jokers.duplicate()
	snapshot.spent_jokers = spent_jokers.duplicate()
	snapshot.enemy_order = enemy_order.duplicate(true)
	snapshot.removed_enemies = removed_enemies.duplicate()
	snapshot.enemy_index = enemy_index
	snapshot.enemy = enemy.duplicate(true)
	snapshot.defeated = defeated
	snapshot.phase = phase
	snapshot.shield = shield
	snapshot.pending_damage = pending_damage
	snapshot.end_reason = end_reason
	return snapshot
