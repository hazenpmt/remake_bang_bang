# Maya building collision: manual tuning

Runtime collision is active for map buildings. Do not hand-edit
`data1_c.godot.json`: re-running the map converter can overwrite it.

Use this file instead:

`assets/battle/maps/Maya Tiên tri(Tính điểm)/data1_c.building_collision_overrides.json`

`buildings` is an optional object. Each key is the placement `unique_id` shown
as `#id` by `EditorMapPreview`; its value is one or more map-pixel rectangles.

Example: this changes only missile turret placement 4.

```json
"4": [
  { "x": 170, "y": 194, "width": 92, "height": 90 }
]
```

Save the JSON then refocus `PvpBattleMap.tscn` in the Godot 2D editor.
`EditorMapPreview` > `Show Npc Collision` draws these orange rectangles, and
the same rectangles are used by runtime movement and basic-shot hit testing.
