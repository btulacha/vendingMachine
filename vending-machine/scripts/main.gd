extends Control

const InventoryStorage = preload("res://scripts/inventory_storage.gd")
const PRICE: int = 2
const INVENTORY_CAPACITY: int = 1000
const COLOR_ICY_AQUA := Color("#ADFCF9")
const COLOR_MUTED_TEAL := Color("#89A894")
const COLOR_HUNTER_GREEN := Color("#4B644A")
const COLOR_DEEP_MOCHA := Color("#49393B")
const COLOR_DARK_COFFEE := Color("#341C1C")
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
const INVENTORY_CATEGORY_NAMES: Array[String] = [
	"Wszystkie",
	"Zbroja",
	"Artefakty",
	"Klejnoty",
	"Rycerze",
	"Zwierzaki",
	"Mikstury",
	"Księgi",
	"Broń",
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
var coin_icon: TextureRect
var coin_button: Button
var tray_pickup_button: Button
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
var inventory_storage
var inventory_page: Control
var inventory_title: Label
var inventory_count_label: Label
var inventory_empty_label: Label
var inventory_tabs_scroll: ScrollContainer
var inventory_tabs_row: HBoxContainer
var inventory_scroll: ScrollContainer
var inventory_grid: GridContainer
var inventory_tab_group: ButtonGroup
var inventory_tab_buttons: Array[Button] = []
var inventory_items: Array[Dictionary] = []
var selected_inventory_category: int = 0
var inventory_open: bool = false
var swipe_tracking: bool = false
var swipe_start_position := Vector2.ZERO
var inventory_transition: Tween


func _ready() -> void:
	randomize()
	inventory_storage = InventoryStorage.new()
	inventory_items = inventory_storage.load_inventory()
	sword_atlas = ResourceLoader.load(SWORD_ATLAS_PATH) as Texture2D
	if sword_atlas == null:
		push_error("Nie udało się załadować arkusza mieczy: %s" % SWORD_ATLAS_PATH)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().physics_object_picking = true
	_create_collision_surfaces()
	_create_packages()
	_create_interface()
	_create_inventory_page()
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
	status_label.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	status_label.add_theme_color_override("font_shadow_color", COLOR_DARK_COFFEE)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	status_label.visible = false

	balance_label = Label.new()
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance_label.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	balance_label.add_theme_font_size_override("font_size", 16)
	add_child(balance_label)

	coin_icon = TextureRect.new()
	coin_icon.texture = load("res://assets/coin.png") as Texture2D
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_icon)

	coin_button = Button.new()
	coin_button.text = "WRZUĆ\n1 DUKAT"
	coin_button.focus_mode = Control.FOCUS_NONE
	coin_button.add_theme_font_size_override("font_size", 13)
	coin_button.pressed.connect(_on_coin_pressed)
	_apply_button_style(coin_button, COLOR_HUNTER_GREEN)
	add_child(coin_button)

	tray_pickup_button = Button.new()
	tray_pickup_button.name = "TrayPickupButton"
	tray_pickup_button.focus_mode = Control.FOCUS_NONE
	tray_pickup_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tray_pickup_button.size = Vector2(76.0, 100.0)
	tray_pickup_button.visible = false
	tray_pickup_button.pressed.connect(_on_tray_pickup_pressed)
	var empty_style := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		tray_pickup_button.add_theme_stylebox_override(state, empty_style)
	add_child(tray_pickup_button)


func _create_inventory_page() -> void:
	inventory_page = Control.new()
	inventory_page.name = "InventoryPage"
	inventory_page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	inventory_page.size = size
	inventory_page.position = Vector2(size.x, 0.0)
	inventory_page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(inventory_page)

	var background := ColorRect.new()
	background.color = COLOR_DARK_COFFEE
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_page.add_child(background)

	var header := ColorRect.new()
	header.color = COLOR_DEEP_MOCHA
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_page.add_child(header)

	inventory_title = Label.new()
	inventory_title.text = "EKWIPUNEK"
	inventory_title.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	inventory_title.add_theme_font_size_override("font_size", 32)
	inventory_page.add_child(inventory_title)

	inventory_count_label = Label.new()
	inventory_count_label.add_theme_color_override("font_color", COLOR_MUTED_TEAL)
	inventory_count_label.add_theme_font_size_override("font_size", 18)
	inventory_page.add_child(inventory_count_label)

	inventory_tabs_scroll = ScrollContainer.new()
	inventory_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_page.add_child(inventory_tabs_scroll)

	inventory_tabs_row = HBoxContainer.new()
	inventory_tabs_row.add_theme_constant_override("separation", 8)
	inventory_tabs_scroll.add_child(inventory_tabs_row)

	inventory_tab_group = ButtonGroup.new()
	for category_index in INVENTORY_CATEGORY_NAMES.size():
		var tab := Button.new()
		tab.text = INVENTORY_CATEGORY_NAMES[category_index]
		tab.toggle_mode = true
		tab.button_group = inventory_tab_group
		tab.button_pressed = category_index == selected_inventory_category
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(96.0, 48.0)
		tab.pressed.connect(_on_inventory_tab_pressed.bind(category_index))
		_apply_button_style(tab, COLOR_HUNTER_GREEN)
		inventory_tab_buttons.append(tab)
		inventory_tabs_row.add_child(tab)

	inventory_scroll = ScrollContainer.new()
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_page.add_child(inventory_scroll)

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 12)
	inventory_scroll.add_child(inventory_grid)

	inventory_empty_label = Label.new()
	inventory_empty_label.text = "Ekwipunek jest pusty"
	inventory_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inventory_empty_label.add_theme_color_override("font_color", COLOR_MUTED_TEAL)
	inventory_empty_label.add_theme_font_size_override("font_size", 22)
	inventory_page.add_child(inventory_empty_label)
	_layout_inventory_page()
	_refresh_inventory_page()


func _layout_inventory_page() -> void:
	if inventory_page == null:
		return
	inventory_page.size = size
	if not inventory_open and not inventory_page.visible:
		inventory_page.position.x = size.x
	inventory_title.position = Vector2(18.0, 6.0)
	inventory_title.size = Vector2(280.0, 46.0)
	inventory_count_label.position = Vector2(300.0, 8.0)
	inventory_count_label.size = Vector2(size.x - 320.0, 42.0)
	inventory_tabs_scroll.position = Vector2(18.0, 68.0)
	inventory_tabs_scroll.size = Vector2(size.x - 36.0, 54.0)
	inventory_scroll.position = Vector2(20.0, 134.0)
	inventory_scroll.size = Vector2(size.x - 40.0, size.y - 154.0)
	inventory_empty_label.position = Vector2(24.0, 240.0)
	inventory_empty_label.size = Vector2(size.x - 48.0, size.y - 320.0)
	var header := inventory_page.get_child(1) as ColorRect
	header.size = Vector2(size.x, 58.0)


func _refresh_inventory_page() -> void:
	if inventory_grid == null:
		return
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	var visible_items: Array[Dictionary] = []
	for item: Dictionary in inventory_items:
		var item_category: int = int(item["category_index"])
		if selected_inventory_category == 0 or item_category == selected_inventory_category:
			visible_items.append(item)
	var is_empty: bool = visible_items.is_empty()
	inventory_empty_label.text = "Ekwipunek jest pusty" if inventory_items.is_empty() else "Brak przedmiotów w tej kategorii"
	inventory_empty_label.visible = is_empty
	inventory_scroll.visible = not is_empty
	inventory_count_label.text = "%d/%d" % [_inventory_item_count(), INVENTORY_CAPACITY]
	for item: Dictionary in visible_items:
		_add_sword_inventory_card(int(item["sword_index"]), int(item["quantity"]))


func _on_inventory_tab_pressed(category_index: int) -> void:
	selected_inventory_category = category_index
	_refresh_inventory_page()


func _inventory_item_count() -> int:
	var total: int = 0
	for item: Dictionary in inventory_items:
		total += int(item["quantity"])
	return total


func _add_inventory_sword(sword_index: int) -> bool:
	if _inventory_item_count() >= INVENTORY_CAPACITY:
		return false
	var category_index: int = INVENTORY_CATEGORY_NAMES.size() - 1
	for stack_index in inventory_items.size():
		var stack: Dictionary = inventory_items[stack_index]
		if int(stack["sword_index"]) == sword_index and int(stack["category_index"]) == category_index:
			stack["quantity"] = int(stack["quantity"]) + 1
			inventory_items[stack_index] = stack
			_save_inventory()
			_refresh_inventory_page()
			return true
	inventory_items.append({
		"sword_index": sword_index,
		"category_index": category_index,
		"quantity": 1,
	})
	_save_inventory()
	_refresh_inventory_page()
	return true


func _save_inventory() -> void:
	var save_error: Error = inventory_storage.save_inventory(inventory_items)
	if save_error != OK:
		push_error("Nie udało się zapisać ekwipunku: %s" % error_string(save_error))


func _add_sword_inventory_card(sword_index: int, quantity: int) -> void:
	var entry := VBoxContainer.new()
	entry.custom_minimum_size = Vector2(112.0, 152.0)
	entry.add_theme_constant_override("separation", 4)
	inventory_grid.add_child(entry)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(112.0, 112.0)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = COLOR_DEEP_MOCHA
	frame_style.border_color = COLOR_MUTED_TEAL
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	icon_frame.add_theme_stylebox_override("panel", frame_style)
	entry.add_child(icon_frame)

	var icon_holder := Control.new()
	icon_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_frame.add_child(icon_holder)

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = sword_atlas
	atlas_texture.region = SWORD_REGIONS[sword_index]
	var icon := TextureRect.new()
	icon.texture = atlas_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)

	var quantity_badge := PanelContainer.new()
	quantity_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quantity_badge.position = Vector2(-34.0, 2.0)
	quantity_badge.size = Vector2(32.0, 32.0)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = COLOR_HUNTER_GREEN
	badge_style.border_color = COLOR_ICY_AQUA
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(16)
	quantity_badge.add_theme_stylebox_override("panel", badge_style)
	icon_holder.add_child(quantity_badge)

	var quantity_label := Label.new()
	quantity_label.text = str(quantity) if quantity < 100 else "99+"
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	quantity_label.add_theme_font_size_override("font_size", 14)
	quantity_badge.add_child(quantity_label)

	var name_label := Label.new()
	name_label.text = SWORD_NAMES[sword_index]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.custom_minimum_size = Vector2(112.0, 36.0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	entry.add_child(name_label)


func _input(event: InputEvent) -> void:
	if opening_package:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_position = event.position
			swipe_tracking = true
		elif swipe_tracking:
			_handle_page_swipe(event.position - swipe_start_position)
			swipe_tracking = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_start_position = event.position
			swipe_tracking = true
		elif swipe_tracking:
			_handle_page_swipe(event.position - swipe_start_position)
			swipe_tracking = false


func _handle_page_swipe(delta: Vector2) -> void:
	if absf(delta.x) < 85.0 or absf(delta.x) < absf(delta.y) * 1.25:
		return
	if inventory_open and swipe_start_position.y >= 108.0 and swipe_start_position.y <= 170.0:
		return
	if inventory_open and delta.x > 0.0:
		_close_inventory()
	elif not inventory_open and delta.x < 0.0:
		_open_inventory()


func _open_inventory() -> void:
	if inventory_open or opening_package:
		return
	inventory_open = true
	_refresh_inventory_page()
	inventory_page.visible = true
	inventory_page.position = Vector2(size.x, 0.0)
	if inventory_transition != null:
		inventory_transition.kill()
	inventory_transition = create_tween()
	inventory_transition.set_trans(Tween.TRANS_CUBIC)
	inventory_transition.set_ease(Tween.EASE_OUT)
	inventory_transition.tween_property(inventory_page, "position:x", 0.0, 0.32)


func _close_inventory() -> void:
	if not inventory_open:
		return
	inventory_open = false
	if inventory_transition != null:
		inventory_transition.kill()
	inventory_transition = create_tween()
	inventory_transition.set_trans(Tween.TRANS_CUBIC)
	inventory_transition.set_ease(Tween.EASE_IN)
	inventory_transition.tween_property(inventory_page, "position:x", size.x, 0.32)
	inventory_transition.finished.connect(_hide_inventory_page)


func _hide_inventory_page() -> void:
	if not inventory_open:
		inventory_page.visible = false

func _layout_controls() -> void:
	_set_reference_rect(status_label, Vector2(14.0, 12.0), Vector2(200.0, 62.0))
	_set_reference_rect(balance_label, Vector2(138.0, 24.0), Vector2(58.0, 36.0))
	_set_reference_rect(coin_icon, Vector2(104.0, 29.0), Vector2(26.0, 26.0))
	_set_reference_rect(coin_button, Vector2(402.0, 466.0), Vector2(76.0, 68.0))
	_layout_inventory_page()


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
		var pending_package: RigidBody2D = package_bodies[index]
		if delivering and _has_reached_tray(pending_package):
			delivering = false
			_update_hud()
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


func _on_tray_pickup_pressed() -> void:
	if pending_index < 0 or delivering or opening_package:
		return
	await _zoom_package_to_front(pending_index)


func _begin_delivery() -> void:
	pending_index = selected_index
	selected_index = -1
	coins_inserted = 0
	delivering = true
	package_available[pending_index] = false
	var package: RigidBody2D = package_bodies[pending_index]
	package.z_as_relative = true
	package.z_index = 0
	physics_world.move_child(package, physics_world.get_child_count() - 1)
	package.collision_mask = TRAY_COLLISION_LAYER
	package.sleeping = false
	var horizontal_impulse: float = 24.0 if package.position.x < 270.0 else -24.0
	package.apply_central_impulse(Vector2(horizontal_impulse, -12.0))
	package.apply_torque_impulse(420.0 if pending_index % 2 == 0 else -420.0)
	_update_hud()

func _physics_process(_delta: float) -> void:
	if pending_index < 0:
		return
	var pending_package: RigidBody2D = package_bodies[pending_index]
	tray_pickup_button.position = pending_package.global_position - tray_pickup_button.size * 0.5
	if delivering and _has_reached_tray(pending_package):
		delivering = false
		_update_hud()


func _has_reached_tray(package: RigidBody2D) -> bool:
	var resting_y: float = TRAY_FLOOR_Y - PACKAGE_COLLISION_SIZE.y * 0.5
	return package.sleeping or package.global_position.y >= resting_y - 4.0


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
	open_prompt.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	open_prompt.add_theme_color_override("font_shadow_color", COLOR_DARK_COFFEE)
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
		await _open_zoomed_package(index)


func _open_zoomed_package(index: int) -> void:
	zoom_ready = false
	if prompt_tween != null:
		prompt_tween.kill()
	open_prompt.queue_free()
	zoom_view.queue_free()
	await _show_contents(index)


func _show_contents(_index: int) -> void:
	var overlay := ColorRect.new()
	overlay.color = COLOR_DARK_COFFEE
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var circle_center := size * 0.5
	var expanding_circle := _create_reveal_circle(overlay, COLOR_MUTED_TEAL)
	expanding_circle.position = circle_center
	expanding_circle.scale = Vector2(0.001, 0.001)
	var cover_radius: float = size.length() * 0.55
	var cover_tween := create_tween()
	cover_tween.set_parallel(true)
	cover_tween.tween_property(
		expanding_circle,
		"scale",
		Vector2(cover_radius, cover_radius),
		0.72
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cover_tween.tween_property(overlay, "modulate:a", 1.0, 0.42)
	await cover_tween.finished

	var medallion_border := _create_reveal_circle(overlay, COLOR_ICY_AQUA)
	medallion_border.position = circle_center
	medallion_border.scale = Vector2.ZERO
	var medallion_center := _create_reveal_circle(overlay, COLOR_HUNTER_GREEN)
	medallion_center.position = circle_center
	medallion_center.scale = Vector2.ZERO
	var medallion_tween := create_tween()
	medallion_tween.set_parallel(true)
	medallion_tween.set_trans(Tween.TRANS_BACK)
	medallion_tween.set_ease(Tween.EASE_OUT)
	medallion_tween.tween_property(medallion_border, "scale", Vector2(144.0, 144.0), 0.48)
	medallion_tween.tween_property(medallion_center, "scale", Vector2(132.0, 132.0), 0.48).set_delay(0.06)
	await medallion_tween.finished

	var sword_index := _roll_sword_index()
	var item_added: bool = _add_inventory_sword(sword_index)
	var sword_region: Rect2 = SWORD_REGIONS[sword_index]
	var sword_texture := AtlasTexture.new()
	sword_texture.atlas = sword_atlas
	sword_texture.region = sword_region
	var sword_size: Vector2 = sword_region.size * 0.58
	var sword_icon := TextureRect.new()
	sword_icon.texture = sword_texture
	sword_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sword_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sword_icon.size = sword_size
	sword_icon.pivot_offset = sword_size * 0.5
	sword_icon.position = circle_center - sword_size * 0.5 + Vector2(0.0, 34.0)
	sword_icon.rotation = -0.22
	sword_icon.scale = Vector2(0.25, 0.25)
	sword_icon.modulate.a = 0.0
	sword_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(sword_icon)

	var reward_label := Label.new()
	reward_label.text = SWORD_NAMES[sword_index].to_upper() if item_added else "EKWIPUNEK PEŁNY"
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	reward_label.add_theme_font_size_override("font_size", 25)
	reward_label.position = Vector2(24.0, circle_center.y + 158.0)
	reward_label.size = Vector2(size.x - 48.0, 44.0)
	reward_label.modulate.a = 0.0
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(reward_label)

	var icon_tween := create_tween()
	icon_tween.set_parallel(true)
	icon_tween.set_trans(Tween.TRANS_BACK)
	icon_tween.set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(sword_icon, "position", circle_center - sword_size * 0.5, 0.48)
	icon_tween.tween_property(sword_icon, "scale", Vector2.ONE, 0.48)
	icon_tween.tween_property(sword_icon, "rotation", 0.0, 0.48)
	icon_tween.tween_property(sword_icon, "modulate:a", 1.0, 0.3)
	icon_tween.tween_property(reward_label, "modulate:a", 1.0, 0.35).set_delay(0.2)
	await icon_tween.finished

	var close_button := Button.new()
	close_button.text = "ZAMKNIJ"
	close_button.position = Vector2(size.x * 0.5 - 90.0, size.y - 118.0)
	close_button.size = Vector2(180.0, 56.0)
	close_button.focus_mode = Control.FOCUS_NONE
	_apply_button_style(close_button, COLOR_HUNTER_GREEN)
	close_button.pressed.connect(_close_contents.bind(overlay, _index))
	overlay.add_child(close_button)


func _roll_sword_index() -> int:
	var roll := randi_range(1, 100)
	var cumulative_weight: int = 0
	for index in SWORD_DROP_WEIGHTS.size():
		cumulative_weight += SWORD_DROP_WEIGHTS[index]
		if roll <= cumulative_weight:
			return index
	return SWORD_DROP_WEIGHTS.size() - 1


func _create_reveal_circle(parent: Node, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	for segment in 128:
		var angle: float = TAU * float(segment) / 128.0
		points.append(Vector2(cos(angle), sin(angle)))
	var circle := Polygon2D.new()
	circle.polygon = points
	circle.color = color
	parent.add_child(circle)
	return circle


func _close_contents(overlay: ColorRect, package_index: int) -> void:
	overlay.queue_free()
	tray_pickup_button.visible = false
	var package: RigidBody2D = package_bodies[package_index]
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
	balance_label.text = str(coins_inserted)
	coin_button.disabled = selected_index < 0 or delivering or pending_index >= 0
	tray_pickup_button.visible = pending_index >= 0 and not delivering and not opening_package
	for index in package_bodies.size():
		package_bodies[index].modulate = COLOR_ICY_AQUA if index == selected_index else Color.WHITE

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
	normal.border_color = COLOR_DEEP_MOCHA
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	normal.shadow_color = Color(0.204, 0.110, 0.110, 0.45)
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
	button.add_theme_color_override("font_color", COLOR_ICY_AQUA)
	button.add_theme_color_override("font_hover_color", COLOR_ICY_AQUA)
	button.add_theme_color_override("font_pressed_color", COLOR_MUTED_TEAL)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED_TEAL)