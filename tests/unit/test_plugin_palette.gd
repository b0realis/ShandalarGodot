extends GutTest
## ADVENTURE PLUGINS — a plugin's own terrain palette ([method
## WorldTerrainPalette.register_profile]): the profile shape of
## docs/terrain-palettes.md in JSON, checked, registered at run time as
## `plugin:<id>`; a save naming an absent plugin's palette stays readable.

const NAME := "plugin:palette_probe"
const OWN := "plugin:refuge"
const DUSK := {"name": "Dusk", "grass": [0.1, 0.8, 1.1, 0.9], "water": [0.6, 1.0, 0.9, 0.8],
	"plain": {"2": "#858855", "6": "c6af78"}, "tints": {"ground": {"tint": "#d9b484", "strength": 0.25}}}


func after_each() -> void:
	WorldTerrainPalette._runtime.erase(NAME)
	WorldTerrainPalette._runtime.erase(OWN)


func test_a_palette_object_is_checked() -> void:
	assert_eq(WorldTerrainPalette.profile_problem(DUSK), "")
	assert_eq(WorldTerrainPalette.profile_problem({}), "", "an empty palette keeps the skin's colors")
	assert_ne(WorldTerrainPalette.profile_problem([]), "")
	assert_string_contains(WorldTerrainPalette.profile_problem({"hue": 1}), "unknown field hue")
	assert_string_contains(WorldTerrainPalette.profile_problem({"grass": [0.1, 0.8, 1.1]}), "grass: four numbers")
	assert_string_contains(WorldTerrainPalette.profile_problem({"water": [0.5, 9, 1, 1]}), "water: four numbers")
	assert_string_contains(WorldTerrainPalette.profile_problem({"plain": {"16": "#000000"}}), "not a terrain code")
	assert_string_contains(WorldTerrainPalette.profile_problem({"plain": {"6": "beige"}}), "a color like")
	assert_string_contains(WorldTerrainPalette.profile_problem({"tints": {"sky": {"tint": "#ffffff", "strength": 0.5}}}), "tints.sky")
	assert_string_contains(WorldTerrainPalette.profile_problem({"tints": {"ground": {"tint": "#ffffff", "strength": 2}}}), "tints.ground")


func test_a_registered_palette_draws_like_a_built_in_one() -> void:
	assert_false(WorldTerrainPalette.has_profile(NAME))
	assert_eq(WorldTerrainPalette.register_profile(NAME, DUSK), "")
	assert_true(WorldTerrainPalette.has_profile(NAME))
	var profile := WorldTerrainPalette.profile_of(NAME)
	assert_eq(profile["name"], "Dusk")
	assert_eq(profile["grass"], Vector4(0.1, 0.8, 1.1, 0.9))
	assert_eq(profile["plain"][6], Color("c6af78"))
	assert_true(WorldTerrainPalette._remaps(NAME), "its grass and water are recolored")
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	assert_true(WorldTerrainPalette.set_preset(world, NAME))
	assert_eq(WorldTerrainPalette.plain(world, 6, Color.WHITE), Color("c6af78"), "its plain colors")
	assert_eq(WorldTerrainPalette.resolve(world, Vector2i(3, 3))["ground"], DUSK["tints"]["ground"], "its default tints")
	assert_ne(WorldTerrainPalette.register_profile(WorldTerrainPalette.LAST_REFUGE, DUSK), "", "a built-in palette stays")
	assert_ne(WorldTerrainPalette.register_profile(NAME, {"grass": 1}), "", "a bad one is refused")
	assert_eq(WorldTerrainPalette.profile_of(NAME)["name"], "Dusk", "and the good one kept")


func test_a_save_naming_an_absent_plugins_palette_stays_readable() -> void:
	assert_true(WorldTerrainPalette.valid_appearance({"preset": "plugin:gone_away"}), "the plugin may come back")
	assert_eq(WorldTerrainPalette.profile_of("plugin:gone_away"), {}, "until then the skin's own colors")
	assert_false(WorldTerrainPalette.valid_appearance({"preset": "plugin:Bad Name"}))
	assert_false(WorldTerrainPalette.valid_appearance({"preset": "neon"}))
	assert_true(WorldTerrainPalette.valid_appearance({"preset": WorldTerrainPalette.LAST_REFUGE}))


func test_a_plugins_palette_object_registers_through_its_descriptor() -> void:
	const Files := preload("res://tests/support/plugin_files.gd")
	var files := Files.folder(Files.REFUGE)
	var manifest := Files.manifest(files)
	manifest["region"]["palette"] = DUSK
	var data: Dictionary = PluginSchema.read(manifest, files)["data"]
	assert_false(data.is_empty())
	var info := PluginSchema.descriptor(manifest, data)
	assert_eq(info["palette"], OWN, "named after the plugin")
	assert_eq(WorldTerrainPalette.profile_of(OWN)["name"], "Dusk")
