extends SceneTree

const ContentDelivery := preload("res://scripts/network/content_delivery.gd")
const ShopCatalog := preload("res://scripts/data/shop_catalog.gd")


func _init() -> void:
	assert(ContentDelivery._valid_asset_id("tank_2026"))
	assert(not ContentDelivery._valid_asset_id("Tank-2026"))
	assert(
		ContentDelivery._absolute_content_url(
			"/content/images/a.png", "http://127.0.0.1:8080/api"
		) == "http://127.0.0.1:8080/content/images/a.png"
	)
	assert(
		ContentDelivery._sha256_bytes("abc".to_utf8_buffer())
		== "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	)
	assert(ContentDelivery.resolve_uri("content://not_cached").is_empty())
	var catalog := {
		"shelves": [{
			"shelf_id": "recommend", "label": "ĐỀ CỬ", "layout": "small"
		}],
		"items": [{
			"item_id": "remote_item",
			"item_type": "material",
			"name": "Remote",
			"description": "",
			"image": "content://not_cached",
			"fallback_image": "res://shop_content/fallback.png",
		}],
		"offers": [{
			"offer_id": "remote_offer",
			"item_id": "remote_item",
			"shelf_ids": ["recommend"],
			"currency": "silver",
			"price": 1,
			"start_at": null,
			"end_at": null,
		}],
	}
	assert(ShopCatalog.apply_server_catalog(catalog))
	var items := ShopCatalog.items(&"recommend")
	assert(items.size() == 1)
	assert(String(items[0].get("image", "")) == "res://shop_content/fallback.png")
	print("CONTENT_DELIVERY_SMOKE_OK")
	quit()
