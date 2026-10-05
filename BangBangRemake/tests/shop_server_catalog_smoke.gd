extends SceneTree


func _initialize() -> void:
	var catalog = load("res://scripts/data/shop_catalog.gd")
	var document := {
		"shelves": [
			{"shelf_id": "recommend", "label": "ĐỀ CỬ", "layout": "small"},
		],
		"items": [
			{
				"item_id": "server_chip",
				"item_type": "material",
				"name": "Chip máy chủ",
				"description": "Dữ liệu do server cấp.",
				"image": "res://assets/ui/profile/item_exp.png",
				"owned": false,
				"owned_quantity": 0,
			},
		],
		"offers": [
			{
				"offer_id": "offer_server_chip",
				"item_id": "server_chip",
				"shelf_ids": ["recommend"],
				"currency": "silver",
				"price": 100,
				"purchase_limit": 3,
				"purchased_quantity": 0,
				"remaining_limit": 3,
			},
		],
	}
	assert(catalog.apply_server_catalog(document))
	var before: Dictionary = catalog.items(&"recommend")[0]
	assert(not before.owned)
	assert(before.remaining_limit == 3)
	catalog.apply_purchase({
		"offer_id": "offer_server_chip",
		"item_id": "server_chip",
		"quantity": 2,
		"grant": {"asset_kind": "item", "balance_after": 2},
	})
	var after: Dictionary = catalog.items(&"recommend")[0]
	assert(after.owned)
	assert(after.owned_quantity == 2)
	assert(after.purchased_quantity == 2)
	assert(after.remaining_limit == 1)
	print("SHOP_SERVER_CATALOG_OK")
	quit()
