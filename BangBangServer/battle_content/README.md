# Battle content

Server battle maps live in `maps/*.json`. The server loads them by `map_key`; do
not trust map geometry, spawn points, rules, damage, range, or cooldown values
sent by a client.

When adding a map, export its original map size, authored team spawns and
collision rectangles into one JSON file, validate it in tests, then register the
map key in `src/battle-map-catalog.js`. Client art stays in the Godot/PCK build;
only gameplay geometry and rules belong here.
