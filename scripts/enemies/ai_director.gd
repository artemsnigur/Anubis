class_name AIDirector
extends Node
## Attack tokens: at most `max_tokens` enemies may attack at the same time, the rest
## circle around the player. Created lazily in the current scene.

var max_tokens: int = 2
var holders: Array[Node] = []
var _cooldown_until: Dictionary = {}


static func get_instance(tree: SceneTree) -> AIDirector:
	var d := tree.get_first_node_in_group(&"ai_director") as AIDirector
	if d == null:
		d = AIDirector.new()
		d.name = "AIDirector"
		var root := tree.current_scene if tree.current_scene != null else tree.root
		root.add_child(d)
	return d


func _ready() -> void:
	add_to_group(&"ai_director")
	max_tokens = GameState.balance.max_attack_tokens


func _clean() -> void:
	for i in range(holders.size() - 1, -1, -1):
		var h := holders[i]
		if not is_instance_valid(h) or bool(h.get("is_dead")):
			holders.remove_at(i)


func request(enemy: Node) -> bool:
	_clean()
	if holders.has(enemy):
		return true
	var now := Time.get_ticks_msec()
	if int(_cooldown_until.get(enemy.get_instance_id(), 0)) > now:
		return false
	if holders.size() >= max_tokens:
		return false
	holders.append(enemy)
	return true


func release(enemy: Node) -> void:
	if holders.has(enemy):
		holders.erase(enemy)
		_cooldown_until[enemy.get_instance_id()] = Time.get_ticks_msec() + int(GameState.balance.token_cooldown * 1000.0)


func has_token(enemy: Node) -> bool:
	return holders.has(enemy)


func debug_text() -> String:
	_clean()
	var names: PackedStringArray = []
	for h in holders:
		names.append(String(h.name))
	return "%d/%d %s" % [holders.size(), max_tokens, ", ".join(names)]
