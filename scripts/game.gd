extends Node
## Persistent game simulation. All scenes read the same state.

signal changed

const SAVE_PATH := "user://crazy_save.json"
const WALL_WOOD_COST := 8
const WALL_STONE_COST := 6

var gold: int = 100
var wood: int = 36
var stone: int = 30
var food: int = 35
var soldiers: int = 6
var threat: int = 12
var raids: int = 0
var player_health: int = 100
var walls: Array = []
var destination: String = "castle"
var village_id: int = 1
var last_report: String = "Заброшенная крепость ждёт нового хозяина."

func _ready() -> void:
	load_game()

func set_destination(where: String, id: int = 1) -> void:
	destination = where
	village_id = id
	save_game()

func can_place_wall() -> bool:
	return wood >= WALL_WOOD_COST and stone >= WALL_STONE_COST and walls.size() < 24

func place_wall(pos: Vector3, yaw: float) -> bool:
	if destination != "castle" or not can_place_wall():
		return false
	if absf(pos.x) > 34.0 or absf(pos.z) > 34.0:
		return false
	wood -= WALL_WOOD_COST
	stone -= WALL_STONE_COST
	walls.append({"x": snappedf(pos.x, 1.0), "z": snappedf(pos.z, 1.0), "yaw": yaw})
	last_report = "Построен участок крепостной стены."
	changed.emit()
	save_game()
	return true

func recruit() -> bool:
	if gold < 25 or food < 3 or soldiers >= 16:
		return false
	gold -= 25
	food -= 3
	soldiers = mini(16, soldiers + 2)
	last_report = "В гарнизон вступили два наёмника."
	changed.emit()
	save_game()
	return true

func finish_raid() -> void:
	var gained_gold := 30 + 10 * village_id
	gold += gained_gold
	wood += 12
	stone += 5
	food += 8
	raids += 1
	threat = mini(100, threat + 18)
	last_report = "Деревня разграблена. Добыча: %d золота, 12 дерева, 5 камня, 8 провизии. Угроза растёт." % gained_gold
	changed.emit()
	save_game()

func finish_defense() -> void:
	gold += 15
	threat = maxi(0, threat - 15)
	last_report = "Нападавшие разбиты. Твой замок устоял. Получено 15 золота."
	changed.emit()
	save_game()

func fail_encounter() -> void:
	gold = maxi(0, gold - 20)
	player_health = 100
	threat = mini(100, threat + 5)
	last_report = "Поражение. Ты отступил и потерял часть казны."
	changed.emit()
	save_game()

func heal_at_camp() -> void:
	if food >= 3:
		food -= 3
		player_health = 100
		last_report = "Отряд отдохнул и восстановил силы."
		changed.emit()
		save_game()

func take_damage(amount: int) -> void:
	player_health = maxi(0, player_health - amount)
	changed.emit()

func save_game() -> bool:
	var data := {
		"version": 1,
		"gold": gold, "wood": wood, "stone": stone, "food": food,
		"soldiers": soldiers, "threat": threat, "raids": raids,
		"player_health": player_health, "walls": walls,
		"destination": destination, "village_id": village_id,
		"last_report": last_report
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write savegame: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("Savegame is invalid: using defaults.")
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != 1:
		push_warning("Unsupported savegame version: using defaults.")
		return false
	gold = maxi(0, int(data.get("gold", gold)))
	wood = maxi(0, int(data.get("wood", wood)))
	stone = maxi(0, int(data.get("stone", stone)))
	food = maxi(0, int(data.get("food", food)))
	soldiers = clampi(int(data.get("soldiers", soldiers)), 0, 16)
	threat = clampi(int(data.get("threat", threat)), 0, 100)
	raids = maxi(0, int(data.get("raids", raids)))
	player_health = clampi(int(data.get("player_health", player_health)), 1, 100)
	var saved_walls: Variant = data.get("walls", [])
	if saved_walls is Array:
		walls = saved_walls
	destination = str(data.get("destination", destination))
	village_id = int(data.get("village_id", village_id))
	last_report = str(data.get("last_report", last_report))
	changed.emit()
	return true
