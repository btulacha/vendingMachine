extends RefCounted

const SAVE_PATH: String = "user://inventory.cfg"
const SAVE_VERSION: int = 1
const CATEGORY_COUNT: int = 9
const SWORD_COUNT: int = 10
const MAX_ITEMS: int = 1000


func load_inventory() -> Array[Dictionary]:
	var config := ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		return []
	if load_error != OK:
		push_warning("Nie udało się odczytać ekwipunku: %s" % error_string(load_error))
		return []

	var saved_items: Variant = config.get_value("inventory", "items", [])
	if typeof(saved_items) != TYPE_ARRAY:
		return []

	var inventory: Array[Dictionary] = []
	var remaining_items: int = MAX_ITEMS
	for saved_item: Variant in saved_items:
		if typeof(saved_item) != TYPE_DICTIONARY:
			continue
		var sword_index: int = int(saved_item.get("sword_index", -1))
		var category_index: int = int(saved_item.get("category_index", -1))
		var quantity: int = int(saved_item.get("quantity", 0))
		if sword_index < 0 or sword_index >= SWORD_COUNT:
			continue
		if category_index < 0 or category_index >= CATEGORY_COUNT or quantity <= 0:
			continue
		if remaining_items <= 0:
			break
		quantity = mini(quantity, remaining_items)
		remaining_items -= quantity
		inventory.append({
			"sword_index": sword_index,
			"category_index": category_index,
			"quantity": quantity,
		})
	return inventory


func save_inventory(inventory: Array[Dictionary]) -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("inventory", "items", inventory)
	return config.save(SAVE_PATH)