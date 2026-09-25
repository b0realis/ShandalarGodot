extends GameTest
## LAYER 4 WITH MORE THAN ONE READER (2026-09-25).
##
## The base pool's dependency step (CR 613.8) was two waves: retypers that
## WRITE a land type, then Conversion, the one card that READS one. Ice
## Age brings Glaciers ("Mountains are Plains" again) and Illusionary
## Terrain, whose two types are chosen as it enters — and a Terrain set to
## "Plains are Forests" READS the very type Conversion WRITES. It is
## dependent on Conversion whichever entered first, so a Mountain under
## both is a Forest. Set the other way ("Plains are Mountains") the two
## depend on each other, and the loop is broken by timestamp order
## (CR 613.8b) — which is also the only order the engine knew before.
## Enabling Ice Age here changes nothing for a base-only install: the
## base pool still has its one reader, pinned by test_layer_order.

const PLAINS := 0
const MOUNTAIN := 3
const FOREST := 4


## Answers Illusionary Terrain's two prompts from a queue, the hint after.
class ChoiceSeat extends DecisionAgent:
	var answers: Array[int] = []

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], hint: int) -> int:
		if answers.is_empty():
			return hint
		return answers.pop_front()


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)


func _terrain(from: int, to: int) -> CardInstance:
	var seat := ChoiceSeat.new()
	seat.answers = [from, to]
	g.agents[0] = seat
	return put_battlefield(0, "Illusionary Terrain")


func test_ice_age_brings_the_pool_two_more_readers() -> void:
	var readers: Array[String] = []
	for card_name in CardRegistry.all_names():
		for ability in CardRegistry.get_card(card_name).static_abilities:
			if ability.reads_land_types:
				readers.append(card_name)
	readers.sort()
	assert_eq(readers, ["Conversion", "Glaciers", "Illusionary Terrain"] as Array[String])


func test_the_readers_say_what_they_read_and_write() -> void:
	var conversion := put_battlefield(0, "Conversion")
	var glaciers := put_battlefield(0, "Glaciers")
	var terrain := _terrain(PLAINS, FOREST)
	for reader in [conversion, glaciers]:
		var edge: Array = reader.data.static_abilities[0].land_type_edge(reader)
		assert_eq(edge, [["mountain"], ["plains"]], reader.data.card_name)
	assert_eq(terrain.data.static_abilities[0].land_type_edge(terrain),
		[["plains"], ["forest"]], "the Terrain answers from its choice")


func test_a_terrain_reading_what_conversion_writes_applies_after_it() -> void:
	_terrain(PLAINS, FOREST)
	put_battlefield(0, "Conversion")
	var mountain := put_battlefield(1, "Mountain")
	var plains := put_battlefield(1, "Plains")
	assert_eq(mountain.cur_subtypes, ["forest"] as Array[String],
		"Mountain -> Plains (Conversion) -> Forest (Terrain), though the Terrain is older")
	assert_eq(plains.cur_subtypes, ["forest"] as Array[String])
	assert_eq(mountain.cur_mana_abilities[0].produces[0][0], Mtg.ManaColor.G)


func test_the_same_pair_in_timestamp_order_agrees() -> void:
	put_battlefield(0, "Conversion")
	_terrain(PLAINS, FOREST)
	var mountain := put_battlefield(1, "Mountain")
	assert_eq(mountain.cur_subtypes, ["forest"] as Array[String])


func test_a_dependency_loop_falls_back_to_timestamps_conversion_first() -> void:
	put_battlefield(0, "Conversion")
	_terrain(PLAINS, MOUNTAIN)
	var mountain := put_battlefield(1, "Mountain")
	var plains := put_battlefield(1, "Plains")
	assert_eq(mountain.cur_subtypes, ["mountain"] as Array[String],
		"Conversion first makes it a Plains, then the Terrain a Mountain again")
	assert_eq(plains.cur_subtypes, ["mountain"] as Array[String])


func test_a_dependency_loop_falls_back_to_timestamps_terrain_first() -> void:
	_terrain(PLAINS, MOUNTAIN)
	put_battlefield(0, "Conversion")
	var mountain := put_battlefield(1, "Mountain")
	var plains := put_battlefield(1, "Plains")
	assert_eq(plains.cur_subtypes, ["plains"] as Array[String],
		"the Terrain first makes it a Mountain, then Conversion a Plains again")
	assert_eq(mountain.cur_subtypes, ["plains"] as Array[String])


func test_two_readers_of_the_same_type_are_independent() -> void:
	put_battlefield(0, "Glaciers")
	put_battlefield(0, "Conversion")
	var mountain := put_battlefield(1, "Mountain")
	assert_eq(mountain.cur_subtypes, ["plains"] as Array[String])


func test_an_unset_terrain_is_no_ones_dependency() -> void:
	var terrain := put_battlefield(0, "Illusionary Terrain")
	terrain.memory.erase("terrain_from")
	terrain.memory.erase("terrain_to")
	put_battlefield(0, "Conversion")
	var mountain := put_battlefield(1, "Mountain")
	assert_eq(terrain.data.static_abilities[0].land_type_edge(terrain), [[], []])
	assert_eq(mountain.cur_subtypes, ["plains"] as Array[String])


func test_blood_moon_still_goes_before_every_reader() -> void:
	_terrain(PLAINS, FOREST)
	put_battlefield(0, "Conversion")
	put_battlefield(0, "Blood Moon")
	var factory := put_battlefield(1, "Mishra's Factory")
	assert_eq(factory.cur_subtypes, ["plains"] as Array[String],
		"Blood Moon first (a writer), then Conversion; the Terrain retypes basics only")
