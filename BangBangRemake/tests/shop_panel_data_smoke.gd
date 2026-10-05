extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/lobby/shop/ShopPanel.tscn") as PackedScene
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame
	var cards := panel.get_node("Window/Content/Cards") as Control
	assert(cards.get_child_count() == 6)
	panel.call("_select_category", 6)
	await process_frame
	await process_frame
	assert(cards.get_child_count() == 6)
	print("SHOP_PANEL_DATA_OK")
	quit()
