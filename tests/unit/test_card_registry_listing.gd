extends GutTest
## WHAT A DIRECTORY LISTING LOOKS LIKE, AND WHY IT IS NOT THE SAME TWICE.
##
## [CardRegistry] finds cards by scanning `res://cards/sets/<set>/` — no
## manifest, the filesystem IS the manifest. That works in a checkout and
## it silently found NOTHING in an exported build, because the two list
## different names for the same card:
##
##   checkout   terror.gd            terror.gd.uid
##   .pck       terror.gdc           terror.gd.remap        (no terror.gd)
##
## Godot compiles every script into the pack and leaves a `.remap` behind
## pointing at it; `load("res://cards/sets/2ed/terror.gd")` still works
## (the remap resolves it), but a listing filtered on `ends_with(".gd")`
## matches neither name. The 2026-09-03 playtest of the first exported
## build is what found it: every deck read as ALL PROXIES and the Deck
## Builder showed an empty pool, because the registry held zero cards.
##
## [method CardRegistry.card_files_in] is the one place that knows this.
## These tests feed it both shapes.

const DEV := ["abomination.gd", "abomination.gd.uid", "air_elemental.gd",
	"air_elemental.gd.uid"]
const EXPORTED := ["abomination.gdc", "abomination.gd.remap",
	"air_elemental.gdc", "air_elemental.gd.remap"]


func test_a_checkout_listing_yields_the_card_scripts() -> void:
	assert_eq(Array(CardRegistry.card_files_in(DEV)),
		["abomination.gd", "air_elemental.gd"])


func test_an_exported_listing_yields_exactly_the_same_names() -> void:
	assert_eq(Array(CardRegistry.card_files_in(EXPORTED)),
		Array(CardRegistry.card_files_in(DEV)),
		"the .pck must answer with the paths load() wants")


func test_the_compiled_script_and_its_remap_are_one_card_not_two() -> void:
	# Both name the same card; registering twice is a duplicate error.
	assert_eq(CardRegistry.card_files_in(
		["terror.gdc", "terror.gd.remap"]).size(), 1)


func test_the_uid_sidecar_is_not_a_card() -> void:
	assert_eq(Array(CardRegistry.card_files_in(["terror.gd.uid"])), [])


func test_an_underscored_file_is_a_helper_not_a_card() -> void:
	assert_eq(Array(CardRegistry.card_files_in(
		["_shared.gd", "_shared.gd.remap", "_shared.gdc"])), [])


func test_anything_that_is_not_a_script_is_ignored() -> void:
	assert_eq(Array(CardRegistry.card_files_in(
		["notes.txt", "art.png", "data.json", ".gitignore"])), [])


func test_the_pool_the_registry_actually_loaded_is_the_whole_pool() -> void:
	# The listing above is a pure function; this is the end of the wire.
	CardRegistry.ensure_loaded()
	assert_eq(CardRegistry.size(), 897)
