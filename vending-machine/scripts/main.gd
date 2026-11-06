extends Control

const PRICE: int = 15
const DESIGN_SIZE := Vector2(540.0, 960.0)
const PACKAGE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/package_armor.png"),
	preload("res://assets/package_env.png"),
	preload("res://assets/package_gem.png"),
	preload("res://assets/package_knights.png"),
	preload("res://assets/package_pet.png"),
	preload("res://assets/package_potion.png"),
	preload("res://assets/package_spellbook.png"),
	preload("res://assets/package_weapon.png"),
]
const SHELF_COLLISION_LAYER: int = 1
const TRAY_COLLISION_LAYER: int = 2
const PACKAGE_COLLISION_LAYER: int = 4
const TRAY_FLOOR_Y: float = 908.0
const PACKAGE_INFO: Array[Dictionary] = [
	{"name": "Paczka 01", "contents": "Zbroja rycerska"},
	{"name": "Paczka 02", "contents": "Tajemniczy artefakt"},
	{"name": "Paczka 03", "contents": "Szmaragd"},
	{"name": "Paczka 04", "contents": "Czarny rubin"},
	{"name": "Paczka 05", "contents": "Zwierzęcy towarzysz"},
	{"name": "Paczka 06", "contents": "Eliksir leczenia"},
	{"name": "Paczka 07", "contents": "Księga zaklęć"},
	{"name": "Paczka 08", "contents": "Miecz"},
]
const SLOT_POSITIONS: Array[Vector2] = [
	Vector2(170.0, 300.0),
	Vector2(305.0, 300.0),
	Vector2(170.0, 442.0),
	Vector2(305.0, 442.0),
	Vector2(170.0, 579.0),
	Vector2(305.0, 579.0),
	Vector2(170.0, 710.0),
	Vector2(305.0, 710.0),
]
const SHELF_TOPS: Array[float] = [330.0, 472.0, 609.0, 740.0]
const PACKAGE_SCALE := Vector2(0.055, 0.055)
const PACKAGE_COLLISION_SIZE := Vector2(38.0, 60.0)

@onready var physics_world: Node2D = $PhysicsWorld

var status_label: Label
var balance_label: Label
var coin_button: Button
var package_bodies: Array[RigidBody2D] = []
var package_available: Array[bool] = []
var selected_index: int = -1
var pending_index: int = -1
var coins_inserted: int = 0
var delivering: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().physics_object_picking = true
	_create_collision_surfaces()
	_create_packages()
	_create_interface()
	_layout_controls()
	_update_hud()
	get_viewport().size_changed.connect(_layout_controls)


func _create_collision_surfaces() -> void:
	for shelf_top: float in SHELF_TOPS:
		var shelf := StaticBody2D.new()
		shelf.position = Vector2(237.5, shelf_top + 5.0)
		shelf.collision_layer = SHELF_COLLISION_LAYER
		shelf.collision_mask = PACKAGE_COLLISION_LAYER
		_add_rectangle_collider(shelf, Vector2(275.0, 10.0))
		physics_world.add_child(shelf)

	var tray := StaticBody2D.new()
	tray.collision_layer = TRAY_COLLISION_LAYER
	tray.collision_mask = PACKAGE_COLLISION_LAYER
	_add_rectangle_collider(tray, Vector2(300.0, 8.0), Vector2(270.0, TRAY_FLOOR_Y + 4.0))
	_add_rectangle_collider(tray, Vector2(10.0, 90.0), Vector2(125.0, TRAY_FLOOR_Y - 45.0))
	_add_rectangle_collider(tray, Vector2(10.0, 90.0), Vector2(415.0, TRAY_FLOOR_Y - 45.0))
	physics_world.add_child(tray)


func _add_rectangle_collider(
	body: CollisionObject2D,
	collider_size: Vector2,
	local_position: Vector2 = Vector2.ZERO
) -> void:
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = collider_size
	collision.position = local_position
	collision.shape = rectangle
	body.add_child(collision)


func _create_packages() -> void:
	for index in PACKAGE_INFO.size():
		var package := RigidBody2D.new()
		package.name = "Package%02d" % (index + 1)
		package.position = SLOT_POSITIONS[index]
		package.gravity_scale = 1.0
		package.angular_damp = 2.0
		package.collision_layer = PACKAGE_COLLISION_LAYER
		package.collision_mask = SHELF_COLLISION_LAYER | TRAY_COLLISION_LAYER
		package.input_pickable = true
		package.input_event.connect(_on_package_input_event.bind(index))
		_add_rectangle_collider(package, PACKAGE_COLLISION_SIZE)

		var sprite := Sprite2D.new()
		sprite.texture = PACKAGE_TEXTURES[index]
		sprite.scale = PACKAGE_SCALE
		package.add_child(sprite)

		package_bodies.append(package)
		package_available.append(true)
		physics_world.add_child(package)


func _create_interface() -> void:
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#fff0c9"))
	status_label.add_theme_color_override("font_shadow_color", Color("#28150b"))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)

	balance_label = Label.new()
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance_label.add_theme_color_override("font_color", Color("#351a0b"))
	balance_label.add_theme_font_size_override("font_size", 16)
	add_child(balance_label)

	coin_button = Button.new()
	coin_button.text = "WRZUĆ\n1 DUKAT"
	coin_button.focus_mode = Control.FOCUS_NONE
	coin_button.add_theme_font_size_override("font_size", 13)
	coin_button.pressed.connect(_on_coin_pressed)
	_apply_button_style(coin_button, Color("#c78a35"))
	add_child(coin_button)

func _layout_controls() -> void:
	_set_reference_rect(status_label, Vector2(14.0, 14.0), Vector2(370.0, 38.0))
	_set_reference_rect(balance_label, Vector2(412.0, 408.0), Vector2(58.0, 34.0))
	_set_reference_rect(coin_button, Vector2(402.0, 466.0), Vector2(76.0, 68.0))


func _set_reference_rect(control: Control, reference_position: Vector2, reference_size: Vector2) -> void:
	var scale_x: float = size.x / DESIGN_SIZE.x
	var scale_y: float = size.y / DESIGN_SIZE.y
	control.position = Vector2(reference_position.x * scale_x, reference_position.y * scale_y)
	control.size = Vector2(reference_size.x * scale_x, reference_size.y * scale_y)


func _on_package_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int,
	index: int
) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return

	if index == pending_index:
		if not delivering:
			_show_contents(index)
		return
	if delivering or pending_index >= 0 or not package_available[index]:
		return
	selected_index = index
	coins_inserted = 0
	_update_hud()


func _on_coin_pressed() -> void:
	if selected_index < 0 or delivering or pending_index >= 0:
		return
	coins_inserted += 1
	if coins_inserted >= PRICE:
		_begin_delivery()
	else:
		_update_hud()


func _begin_delivery() -> void:
	pending_index = selected_index
	selected_index = -1
	coins_inserted = 0
	delivering = true
	package_available[pending_index] = false
	var package: RigidBody2D = package_bodies[pending_index]
	package.collision_mask = TRAY_COLLISION_LAYER
	package.sleeping = false
	var horizontal_impulse: float = 24.0 if package.position.x < 270.0 else -24.0
	package.apply_central_impulse(Vector2(horizontal_impulse, -12.0))
	package.apply_torque_impulse(420.0 if pending_index % 2 == 0 else -420.0)
	_update_hud()

func _physics_process(_delta: float) -> void:
	if delivering and package_bodies[pending_index].sleeping:
		delivering = false
		_update_hud()


func _show_contents(index: int) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.025, 0.015, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(size.x * 0.86, 420.0), 250.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#4a2818")
	panel_style.border_color = Color("#d49a45")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ZAWARTOŚĆ PACZKI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#f4cb78"))
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	var contents := Label.new()
	contents.text = str(PACKAGE_INFO[index]["contents"])
	contents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_theme_color_override("font_color", Color("#fff3dc"))
	contents.add_theme_font_size_override("font_size", 26)
	column.add_child(contents)

	var close_button := Button.new()
	close_button.text = "ZAMKNIJ"
	close_button.custom_minimum_size = Vector2(0.0, 52.0)
	close_button.focus_mode = Control.FOCUS_NONE
	_apply_button_style(close_button, Color("#a85e30"))
	close_button.pressed.connect(_close_contents.bind(overlay))
	column.add_child(close_button)


func _close_contents(overlay: ColorRect) -> void:
	overlay.queue_free()
	var package: RigidBody2D = package_bodies[pending_index]
	package.visible = false
	package.input_pickable = false
	package.collision_layer = 0
	package.collision_mask = 0
	package.freeze = true
	pending_index = -1
	_update_hud()


func _update_hud() -> void:
	balance_label.text = "%d/%d" % [coins_inserted, PRICE]
	coin_button.disabled = selected_index < 0 or delivering or pending_index >= 0
	for index in package_bodies.size():
		package_bodies[index].modulate = Color("#ffd98c") if index == selected_index else Color.WHITE

	if delivering:
		status_label.text = "Paczka w drodze do podajnika"
	elif pending_index >= 0:
		status_label.text = "Paczka czeka w dolnym podajniku"
	elif selected_index >= 0:
		status_label.text = "%s  |  Cena: %d dukatów" % [PACKAGE_INFO[selected_index]["name"], PRICE]
	else:
		status_label.text = "Wybierz paczkę na półce"


func _apply_button_style(button: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color("#432315")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	normal.shadow_size = 3
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.13)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.13)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", Color("#fff1d2"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#f8dfb2"))
	button.add_theme_color_override("font_disabled_color", Color("#9a816c"))