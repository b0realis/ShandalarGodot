extends RefCounted
## Deliberately different development fixture: eight tiles wide, no castle,
## no pledges, no card pool, no images, three beacons. Never registered on boot.
const ID := "beacon_test"

static func descriptor() -> Dictionary:
	return {"title": "Beacon Test Island", "provider": "res://tools/expansion_testing/beacon_region.gd", "salt": 9517,
		"required_markers": ["port"], "mana_links": false,
		"initial_progress": {"lit": 0, "complete": false},
		"progress_schema": {"fields": {"lit": {"type": "int", "min": 0, "max": 3}, "complete": {"type": "bool"}}}}

static func generate(seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	var world := ShandalarWorld.new()
	world.seed = seed_value
	world.rand_state = seed_value
	world.color = color
	world.difficulty = difficulty
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in range(28, 36):
		for x in range(28, 36): world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 2
	for i in 128: world.sites.append({"type": 0, "x": 0, "y": 0, "trade": 0, "status": 0})
	world.start = Vector2i(28, 32) * 32 + Vector2i(16, 16)
	world.expansion = {"region": ID, "port": [28, 32]}
	return world

static func task_rows(_data: Dictionary, progress: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not progress.get("complete", false):
		out.append(AdventureTasks.row("light", ID, "Light the beacons", "%d of 3 lit." % progress.get("lit", 0), Vector2i(33, 30)))
	return out
