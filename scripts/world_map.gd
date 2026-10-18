extends Control
## World map: one coherent state, no cloned RPG/RTS simulations.

var status_label: Label
var report_label: Label

func _ready() -> void:
	Game.changed.connect(_refresh)
	_make_label("CRAZY", Vector2(42, 20), Vector2(450, 70), 46, Color("#e5c586"))
	_make_label("DARK LORD RPG  •  КОРОНА И ПЕПЕЛ", Vector2(46, 88), Vector2(700, 30), 17, Color("#b18b80"))
	_make_label("СЕВЕРНОЕ ПОГРАНИЧЬЕ", Vector2(65, 152), Vector2(530, 38), 25, Color("#e5c586"))
	_make_label("Глобальная карта • выбери место, чтобы войти в 3D", Vector2(65, 192), Vector2(690, 25), 15, Color("#c1a993"))

	_make_button("◈  МОЙ ЗАМОК", Vector2(320, 315), Vector2(190, 56), func(): _open("castle"))
	_make_button("◉  ДЕРЕВНЯ I", Vector2(90, 460), Vector2(180, 46), func(): _open("village", 1))
	_make_button("◉  ДЕРЕВНЯ II", Vector2(610, 425), Vector2(180, 46), func(): _open("village", 2))
	_make_button("♣  ЛЕСНОЙ ЛАГЕРЬ", Vector2(500, 240), Vector2(215, 46), func(): _open("camp"))

	var panel := Panel.new()
	panel.position = Vector2(872, 115)
	panel.size = Vector2(372, 515)
	add_child(panel)
	_make_label("ТВОИ ВЛАДЕНИЯ", Vector2(901, 136), Vector2(310, 32), 24, Color("#ead7ab"))
	status_label = _make_label("", Vector2(901, 193), Vector2(325, 276), 19, Color("#e9e5d9"))
	_make_button("СОХРАНИТЬ ИГРУ", Vector2(901, 540), Vector2(310, 53), func(): _save())

	report_label = _make_label("", Vector2(58, 632), Vector2(1160, 76), 16, Color("#e8cc96"))
	_make_label("Вертикальный срез • путь героя и тёмного властелина", Vector2(58, 605), Vector2(820, 23), 13, Color("#896d67"))
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("#100e12"))
	draw_rect(Rect2(38, 132, 796, 445), Color("#211c21"))
	draw_rect(Rect2(40, 134, 792, 441), Color("#2b2021"), false, 2.0)
	var land := PackedVector2Array([
		Vector2(88, 252), Vector2(181, 210), Vector2(318, 237), Vector2(460, 182),
		Vector2(729, 245), Vector2(807, 345), Vector2(716, 536),
		Vector2(423, 543), Vector2(267, 520), Vector2(79, 419)
	])
	draw_colored_polygon(land, Color("#30372e"))
	var roads := [Vector2(410, 343), Vector2(179, 474), Vector2(410, 343), Vector2(687, 440), Vector2(410, 343), Vector2(600, 263)]
	for n in range(0, roads.size(), 2):
		draw_line(roads[n], roads[n + 1], Color("#6c5141"), 7.0, true)
		draw_line(roads[n], roads[n + 1], Color("#a17351"), 2.0, true)
	for p in [Vector2(137, 315), Vector2(294, 274), Vector2(570, 485), Vector2(720, 330)]:
		draw_circle(p, 22, Color("#211b1e"))
		draw_circle(p, 13, Color("#4c171c"))
		draw_circle(p, 5, Color("#d67835"))

func _make_label(txt: String, pos: Vector2, dims: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = txt
	label.position = pos
	label.size = dims
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color("#080607"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func _make_button(txt: String, pos: Vector2, dims: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = txt
	button.position = pos
	button.size = dims
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#eadbc6"))
	button.add_theme_color_override("font_hover_color", Color("#ffbb77"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.pressed.connect(callback)
	add_child(button)
	return button

func _open(where: String, which: int = 1) -> void:
	Game.set_destination(where, which)
	get_tree().change_scene_to_file("res://scenes/location.tscn")

func _save() -> void:
	Game.save_game()
	_refresh()

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = (
		"Золото: %d\nДерево: %d\nКамень: %d\nПровизия: %d\n\n"
		+ "Солдаты: %d\nУгроза королевству: %d/100\n"
		+ "Набеги: %d\nПостроено стен: %d\nЗдоровье: %d/100"
	) % [Game.gold, Game.wood, Game.stone, Game.food, Game.soldiers, Game.threat, Game.raids, Game.walls.size(), Game.player_health]
	report_label.text = "ВЕСТИ: " + Game.last_report
