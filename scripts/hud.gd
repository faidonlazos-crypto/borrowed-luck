class_name Hud extends CanvasLayer

signal machine_choice(choice: int)

var _wave_label: Label
var _enemies_label: Label
var _banner_label: Label
var _hearts_root: Node2D
var _pause_overlay: Control
var _game_over_overlay: Control
var _victory_overlay: Control
var _hint_label: Label
var _machine_panel: Control
var _ordinary_button: Button
var _borrowed_button: Button

var _heart_full: Array[Polygon2D] = []
var _heart_empty: Array[Polygon2D] = []
var _heart_half: Array[Node2D] = []
var _built_max_health: int = 0

const HEART_FULL_COLOR: Color = Color(0.92, 0.22, 0.28, 1.0)
const HEART_EMPTY_COLOR: Color = Color(0.28, 0.26, 0.32, 1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_labels()
	_build_hearts(6)
	_pause_overlay = _make_overlay("Paused", "Esc = resume\nR = restart")
	_game_over_overlay = _make_overlay("Game Over", "R = restart\nEsc = quit")
	_victory_overlay = _make_overlay("Victory!", "R = restart\nEsc = quit")
	add_child(_pause_overlay)
	add_child(_game_over_overlay)
	add_child(_victory_overlay)
	_build_machine_panel()


func set_health(current: int, maximum: int) -> void:
	if maximum > 0 and maximum != _built_max_health:
		_build_hearts(maximum)
	var heart_count := _heart_full.size()
	for i in heart_count:
		var full_at := (i + 1) * 2
		var half_at := i * 2 + 1
		var is_full := current >= full_at
		var is_half := current == half_at
		_heart_full[i].visible = is_full
		_heart_empty[i].visible = not is_full and not is_half
		_heart_half[i].visible = is_half


func set_wave(current: int, total: int) -> void:
	if _wave_label != null:
		_wave_label.text = "Wave %d/%d" % [current, total]


func set_enemies(count: int) -> void:
	if _enemies_label != null:
		_enemies_label.text = "Enemies: %d" % count


func show_banner(text: String) -> void:
	if _banner_label != null:
		_banner_label.text = text
		_banner_label.visible = true


func hide_banner() -> void:
	if _banner_label != null:
		_banner_label.visible = false


func set_pause_visible(visible_value: bool) -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = visible_value


func show_game_over() -> void:
	hide_overlays()
	if _game_over_overlay != null:
		_game_over_overlay.visible = true


func show_victory() -> void:
	hide_overlays()
	if _victory_overlay != null:
		_victory_overlay.visible = true


func set_machine_hint(text: String, greyed: bool) -> void:
	if _hint_label == null:
		return
	_hint_label.text = text
	_hint_label.visible = text != ""
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.56, 0.62, 1.0) if greyed else Color(1.0, 0.85, 0.35, 1.0))


func show_machine_panel(ordinary_text: String, borrowed_text: String, borrowed_enabled: bool) -> void:
	if _machine_panel == null:
		return
	_ordinary_button.text = ordinary_text
	_borrowed_button.text = borrowed_text + ("" if borrowed_enabled else "  (full health)")
	_borrowed_button.disabled = not borrowed_enabled
	_machine_panel.visible = true


func hide_machine_panel() -> void:
	if _machine_panel != null:
		_machine_panel.visible = false


func hide_overlays() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = false
	if _game_over_overlay != null:
		_game_over_overlay.visible = false
	if _victory_overlay != null:
		_victory_overlay.visible = false


func _build_labels() -> void:
	_wave_label = Label.new()
	_wave_label.position = Vector2(18.0, 10.0)
	_wave_label.size = Vector2(240.0, 28.0)
	_wave_label.add_theme_font_size_override("font_size", 22)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_wave_label.text = "Wave 1/3"
	add_child(_wave_label)

	_enemies_label = Label.new()
	_enemies_label.position = Vector2(18.0, 38.0)
	_enemies_label.size = Vector2(240.0, 28.0)
	_enemies_label.add_theme_font_size_override("font_size", 20)
	_enemies_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	_enemies_label.text = "Enemies: 0"
	add_child(_enemies_label)

	_banner_label = Label.new()
	_banner_label.position = Vector2(340.0, 120.0)
	_banner_label.size = Vector2(600.0, 80.0)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 48)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_banner_label.visible = false
	add_child(_banner_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(390.0, 648.0)
	_hint_label.size = Vector2(500.0, 30.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.visible = false
	add_child(_hint_label)

	_hearts_root = Node2D.new()
	_hearts_root.position = Vector2(0.0, 0.0)
	add_child(_hearts_root)


func _build_hearts(max_health: int) -> void:
	if _hearts_root == null:
		return
	for child in _hearts_root.get_children():
		_hearts_root.remove_child(child)
		child.free()
	_heart_full.clear()
	_heart_empty.clear()
	_heart_half.clear()
	_built_max_health = max_health

	var heart_count := maxi(1, int(ceil(float(max_health) / 2.0)))
	for i in heart_count:
		var center := Vector2(34.0 + float(i) * 38.0, 88.0)

		var empty_heart := Polygon2D.new()
		empty_heart.polygon = _heart_points()
		empty_heart.color = HEART_EMPTY_COLOR
		empty_heart.position = center
		_hearts_root.add_child(empty_heart)
		_heart_empty.append(empty_heart)

		var half_root := Node2D.new()
		half_root.position = center
		var half_bg := Polygon2D.new()
		half_bg.polygon = _heart_points()
		half_bg.color = HEART_EMPTY_COLOR
		half_root.add_child(half_bg)
		var half_fg := Polygon2D.new()
		half_fg.polygon = _heart_left_points()
		half_fg.color = HEART_FULL_COLOR
		half_root.add_child(half_fg)
		half_root.visible = false
		_hearts_root.add_child(half_root)
		_heart_half.append(half_root)

		var full_heart := Polygon2D.new()
		full_heart.polygon = _heart_points()
		full_heart.color = HEART_FULL_COLOR
		full_heart.position = center
		_hearts_root.add_child(full_heart)
		_heart_full.append(full_heart)


func _heart_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 14.0),
		Vector2(-13.0, 2.0),
		Vector2(-15.0, -7.0),
		Vector2(-9.0, -14.0),
		Vector2(-3.0, -13.0),
		Vector2(0.0, -7.0),
		Vector2(3.0, -13.0),
		Vector2(9.0, -14.0),
		Vector2(15.0, -7.0),
		Vector2(13.0, 2.0),
	])


func _heart_left_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 14.0),
		Vector2(-13.0, 2.0),
		Vector2(-15.0, -7.0),
		Vector2(-9.0, -14.0),
		Vector2(-3.0, -13.0),
		Vector2(0.0, -7.0),
	])


func _build_machine_panel() -> void:
	_machine_panel = Control.new()
	_machine_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_machine_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_machine_panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_machine_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_machine_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "Luck machine"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	box.add_child(title)
	_ordinary_button = _make_choice_button(box, 1)
	_borrowed_button = _make_choice_button(box, 2)
	var cancel_button := _make_choice_button(box, 0)
	cancel_button.text = "Esc — Cancel"
	add_child(_machine_panel)


func _make_choice_button(parent: Container, choice: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(980.0, 46.0)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(func() -> void: machine_choice.emit(choice))
	parent.add_child(button)
	return button


func _make_overlay(title: String, subtitle: String) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.65)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)

	var label := Label.new()
	label.text = title + "\n" + subtitle
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)

	return overlay
