extends GutTest
## THE LAST REFUGE'S ISLAND, EXACTLY (adventure plugins, 2026-11-10). The
## fingerprints in island_generator_golden.json were captured from the
## built-in RefugeWorld.generate before the data-driven generator replaced
## it: 70 seed x color x difficulty cases — the whole page, every site,
## encounter, world magic, the start, the dice left over and the region's
## metadata — plus the objectives the old quests picked. A saved island that
## was never visited is rebuilt from its seed, so the plugin's recipe must
## make the same island to the bit.

const GOLDEN := "res://tests/unit/island_generator_golden.json"


static func digest(world: ShandalarWorld) -> Dictionary:
	var rest := {"sites": world.sites, "encounters": world.encounters, "magic": world.world_magic_sites,
		"lairs": world.lair_respawn, "start": [world.start.x, world.start.y], "rand": world.rand_state,
		"seed": world.seed, "color": world.color, "difficulty": world.difficulty}
	return {"fingerprint": world.fingerprint(), "page": world.page.hex_encode().sha256_text(),
		"rest": JSON.stringify(rest, "", true).sha256_text(),
		"expansion": JSON.stringify(world.expansion, "", true).sha256_text(),
		"port": world.expansion.get("port", []), "castle": world.expansion.get("castle", [])}


static func cases() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	return parsed["cases"] if parsed is Dictionary else []


const Files := preload("res://tests/support/plugin_files.gd")

var refuge: DataRegion


func before_all() -> void:
	refuge = Files.refuge()


## The prototype plugin's recipe through the data-driven generator.
func make(seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	return IslandGenerator.generate(refuge.data()["world"], seed_value, color, difficulty)


## The objectives the plugin's interpreter picks on arrival.
func objectives(world: ShandalarWorld) -> Dictionary:
	var hero := AdventurePlayer.new()
	hero.world = world
	refuge.ensure_objectives(hero)
	return world.expansion.get("objectives", {})


func test_the_prototype_plugin_reads_clean() -> void:
	var read := Files.read()
	assert_eq(read["problems"], [] as Array[String])
	assert_false(read["data"].is_empty())


func test_the_provider_generates_the_same_island() -> void:
	var world := refuge.generate(48271, 3, 2)
	assert_eq(world.fingerprint(), make(48271, 3, 2).fingerprint())
	assert_eq(world.expansion["region"], "refuge")


func test_the_golden_file_holds_at_least_forty_cases() -> void:
	var rows := cases()
	assert_gte(rows.size(), 40)
	var colors := {}
	var levels := {}
	for row in rows:
		colors[int(row["case"][1])] = true
		levels[int(row["case"][2])] = true
	assert_eq(colors.size(), 5, "every color")
	assert_eq(levels.size(), 4, "every difficulty")


func test_every_golden_island_is_made_again_to_the_bit() -> void:
	for row in cases():
		var key: Array = row["case"]
		var world := make(int(key[0]), int(key[1]), int(key[2]))
		var made := digest(world)
		for field in ["fingerprint", "page", "rest", "expansion"]:
			assert_eq(made[field], row[field], "%s of %s" % [field, key])
		assert_eq(made["port"], row["port"].map(func(n: float) -> int: return int(n)), "port of %s" % [key])
		assert_eq(made["castle"], row["castle"].map(func(n: float) -> int: return int(n)), "castle of %s" % [key])
		var picked := objectives(world)
		for name in row["objectives"]:
			assert_eq(int(picked.get(name, -99)), int(row["objectives"][name]), "objective %s of %s" % [name, key])
