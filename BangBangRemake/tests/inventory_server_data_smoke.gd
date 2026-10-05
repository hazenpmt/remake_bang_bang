extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/lobby/InventoryPanel.tscn") as PackedScene
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame
	var items: Array[Dictionary] = [
		{
			"item_id": "bundle_1",
			"item_type": "bundle",
			"name": "Gói thử",
			"image": "res://assets/ui/profile/item_exp.png",
			"owned_quantity": 2,
		},
	]
	for index in 46:
		items.append({
			"item_id": "material_%d" % index,
			"item_type": "material",
			"name": "Nguyên liệu %d" % index,
			"image": "res://assets/ui/profile/item_exp.png",
			"owned_quantity": index + 1,
		})
	panel.call("_apply_server_inventory", {"items": items})
	assert(panel.call("get_item_page_count") == 1)
	assert(panel.call("get_material_page_count") == 2)
	var item_slot := panel.get_node(
		"Window/ContentFrame/Viewport/ItemsView/ItemGrid/Slot0"
	) as TextureRect
	assert(item_slot.get_child_count() == 2)
	panel.call("_set_material_page", 2)
	var material_slot := panel.get_node(
		"Window/ContentFrame/Viewport/MaterialsView/ItemGrid/Slot0"
	) as TextureRect
	assert(material_slot.get_child_count() >= 1)
	print("INVENTORY_SERVER_DATA_OK")
	quit()
