extends Control

const PRICE: int = 2
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
const SWORD_ATLAS_PATH: String = "res://assets/swords.png"
const SWORD_REGIONS: Array[Rect2] = [
	Rect2(53.0, 251.0, 128.0, 314.0),
	Rect2(252.0, 210.0, 132.0, 355.0),
	Rect2(444.0, 179.0, 152.0, 386.0),
	Rect2(651.0, 153.0, 165.0, 412.0),
	Rect2(859.0, 124.0, 178.0, 441.0),
	Rect2(1068.0, 110.0, 189.0, 455.0),
	Rect2(1287.0, 82.0, 177.0, 483.0),
	Rect2(1497.0, 61.0, 185.0, 508.0),
	Rect2(1705.0, 39.0, 199.0, 530.0),
	Rect2(1897.0, 0.0, 261.0, 569.0),
]
const SWORD_NAMES: Array[String] = [
	"Zardzewiały miecz",
	"Krótki miecz",
	"Stalowy miecz",
	"Miecz gwardzisty",
	"Miecz rycerski",
	"Szafirowy miecz",
	"Ostrze błękitu",
	"Ostrze ametystu",
	"Ostrze rubinu",
	"Miecz legendarny",
]
const SWORD_DROP_WEIGHTS: Array[int] = [30, 24, 18, 12, 7, 4, 2, 1, 1, 1]
const SWORD_PACKAGE_INDEX: int = 7
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
	Vector2(170.0, 294.0),
	Vector2(305.0, 294.0),
	Vector2(170.0, 436.0),
	Vector2(305.0, 436.0),
	Vector2(170.0, 573.0),
	Vector2(305.0, 573.0),
	Vector2(170.0, 704.0),
	Vector2(305.0, 704.0),
]
const SHELF_TOPS: Array[float] = [330.0, 472.0, 609.0, 740.0]
const PACKAGE_SCALE := Vector2(0.066, 0.066)
const PACKAGE_COLLISION_SIZE := Vector2(45.6, 72.0)

@onready var physics_world: Node2D = $PhysicsWorld

var sword_atlas: Texture2D
var status_label: Label
var balance_label: Label
var coin_button: Button
var package_bodies: Array[RigidBody2D] = []
var package_available: Array[bool] = []
var selected_index: int = -1
var pending_index: int = -1
var coins_inserted: int = 0
var delivering: bool = false
var opening_package: bool = false
var zoom_ready: bool = false
var zoom_view: TextureRect
var open_prompt: Label
var prompt_tween: Tween


func _ready() -> void:
	randomize()
	sword_atlas = ResourceLoader.load(SWORD_ATLAS_PATH) as Texture2D
	if sword_atlas == null:
		push_error("Nie udało się załadować arkusza mieczy: %s" % SWORD_ATLAS_PATH)
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
		if not delivering and not opening_package:
			await _zoom_package_to_front(index)
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


func _zoom_package_to_front(index: int) -> void:
	opening_package = true
	zoom_ready = false
	var package: RigidBody2D = package_bodies[index]
	package.freeze = true
	package.input_pickable = false
	package.collision_layer = 0
	package.collision_mask = 0
	package.visible = false
	_update_hud()

	var texture_size: Vector2 = PACKAGE_TEXTURES[index].get_size() * PACKAGE_SCALE
	zoom_view = TextureRect.new()
	zoom_view.texture = PACKAGE_TEXTURES[index]
	zoom_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zoom_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zoom_view.mouse_filter = Control.MOUSE_FILTER_STOP
	zoom_view.size = texture_size
	zoom_view.position = package.global_position - texture_size * 0.5
	zoom_view.gui_input.connect(_on_zoom_view_input.bind(index))
	add_child(zoom_view)

	var max_zoom_size := Vector2(size.x * 0.72, size.y * 0.3)
	var zoom_factor: float = minf(
		max_zoom_size.x / texture_size.x,
		max_zoom_size.y / texture_size.y
	)
	var target_size: Vector2 = texture_size * zoom_factor
	var target_position: Vector2 = size * 0.5 - target_size * 0.5
	var zoom_tween := create_tween()
	zoom_tween.set_parallel(true)
	zoom_tween.set_trans(Tween.TRANS_BACK)
	zoom_tween.set_ease(Tween.EASE_OUT)
	zoom_tween.tween_property(zoom_view, "position", target_position, 0.55)
	zoom_tween.tween_property(zoom_view, "size", target_size, 0.55)
	await zoom_tween.finished

	open_prompt = Label.new()
	open_prompt.text = ">> OPEN <<"
	open_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	open_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	open_prompt.position = Vector2(target_position.x, target_position.y + target_size.y + 16.0)
	open_prompt.size = Vector2(target_size.x, 52.0)
	open_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	open_prompt.add_theme_color_override("font_color", Color("#ffe29a"))
	open_prompt.add_theme_color_override("font_shadow_color", Color("#35170b"))
	open_prompt.add_theme_constant_override("shadow_offset_x", 2)
	open_prompt.add_theme_constant_override("shadow_offset_y", 2)
	open_prompt.add_theme_font_size_override("font_size", 28)
	open_prompt.gui_input.connect(_on_zoom_view_input.bind(index))
	add_child(open_prompt)

	zoom_ready = true
	_update_hud()
	prompt_tween = create_tween().set_loops()
	prompt_tween.tween_property(open_prompt, "modulate:a", 0.35, 0.55)
	prompt_tween.tween_property(open_prompt, "modulate:a", 1.0, 0.55)


func _on_zoom_view_input(event: InputEvent, index: int) -> void:
	if not zoom_ready or index != pending_index:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		_open_zoomed_package(index)


func _open_zoomed_package(index: int) -> void:
	zoom_ready = false
	if prompt_tween != null:
		prompt_tween.kill()
	open_prompt.queue_free()
	zoom_view.queue_free()
	_show_contents(index)


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

	var reward_name := str(PACKAGE_INFO[index]["contents"])
	if index == SWORD_PACKAGE_INDEX and sword_atlas != null:
		var sword_index := _roll_sword_index()
		var sword_texture := AtlasTexture.new()
		sword_texture.atlas = sword_atlas
		sword_texture.region = SWORD_REGIONS[sword_index]

		var sword_icon := TextureRect.new()
		sword_icon.texture = sword_texture
		sword_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sword_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sword_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sword_icon.custom_minimum_size = SWORD_REGIONS[sword_index].size * 0.28
		sword_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sword_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(sword_icon)
		reward_name = SWORD_NAMES[sword_index]

	var contents := Label.new()
	contents.text = reward_name
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


func _roll_sword_index() -> int:
	var roll := randi_range(1, 100)
	var cumulative_weight: int = 0
	for index in SWORD_DROP_WEIGHTS.size():
		cumulative_weight += SWORD_DROP_WEIGHTS[index]
		if roll <= cumulative_weight:
			return index
	return SWORD_DROP_WEIGHTS.size() - 1


func _close_contents(overlay: ColorRect) -> void:
	overlay.queue_free()
	var package: RigidBody2D = package_bodies[pending_index]
	package.visible = false
	package.input_pickable = false
	package.collision_layer = 0
	package.collision_mask = 0
	package.freeze = true
	pending_index = -1
	opening_package = false
	zoom_ready = false
	_update_hud()


func _update_hud() -> void:
	balance_label.text = "%d/%d" % [coins_inserted, PRICE]
	coin_button.disabled = selected_index < 0 or delivering or pending_index >= 0
	for index in package_bodies.size():
		package_bodies[index].modulate = Color("#ffd98c") if index == selected_index else Color.WHITE

	if delivering:
		status_label.text = "Paczka w drodze do podajnika"
	elif opening_package:
		status_label.text = "Kliknij paczkę, aby ją otworzyć" if zoom_ready else "Paczka zbliża się..."
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