extends SceneTree


func _initialize() -> void:
	var catalog = load("res://scripts/data/shop_catalog.gd")
	catalog.reload()
	var errors: PackedStringArray = catalog.validation_errors()
	assert(errors.is_empty(), "Shop catalog errors: %s" % errors)
	assert(catalog.items(&"recommend").size() == 6)
	assert(catalog.items(&"tank").size() == 3)
	assert(catalog.items(&"material").size() == 6)
	var first: Dictionary = catalog.items(&"recommend")[0]
	assert(first.has("item_id") and first.has("offer_id"))
	assert(first.item_id == "adult_gift")
	assert(first.offer_id == "offer_adult_gift")
	assert(catalog.is_large(&"tank"))
	assert(not catalog.is_large(&"recommend"))
	var external_image_path := ProjectSettings.globalize_path(
		"res://assets/ui/profile/item_exp.png"
	)
	assert(catalog.load_texture(external_image_path) != null)
	print("SHOP_EXTERNAL_CATALOG_OK")
	quit()
