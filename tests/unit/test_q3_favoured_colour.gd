extends GutTest
## THE TOWN'S FAVOURED COLOUR, AS PLAYED (the quick world package, 2026-10-27,
## I-1 — kept as played, not asked): 1.3's `RunTownServicesMenu` (0x004ef1ea,
## visitLocation.c 1672–1684) drew `internal_rand(5) + 1` 199 times on each
## town entry and kept a draw that is a colour of the town's land and either
## of an amulet the hero holds or past the 80th pass — with no stop, so each
## kept draw overwrote the last. Passes 81–198 keep any colour of the land:
## the last of them wins, one uniform draw among the land's colours, and the
## held amulets never matter (all 118 late draws would have to miss: at most
## 0.8^118). [CardTrade.arrive] makes that one draw. These pin it: the odds
## split evenly, whatever the hero holds.

var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## A town or a city whose land has exactly two colours, and those colours.
func _two_coloured_town() -> Array:
	for slot in player.world.sites.size():
		var kind := int(player.world.sites[slot]["type"])
		if kind < ShandalarWorld.TOWN or kind >= ShandalarWorld.CASTLE:
			continue
		var mask := CardShop.town_colors(player.world, slot)
		var hues: Array[String] = []
		for i in CardShop.COLOR_BITS.size():
			if mask & CardShop.COLOR_BITS[i] != 0:
				hues.append(AdventurePlayer.COLORS[i])
		if hues.size() == 2:
			return [slot, hues]
	return []


## How often each colour is wanted over [param times] arrivals.
func _wanted(slot: int, times: int) -> Dictionary:
	var counts := {}
	for i in times:
		CardTrade.arrive(player, slot)
		var want := String(player.shops[str(slot)]["want"])
		counts[want] = int(counts.get(want, 0)) + 1
	return counts


func test_two_colours_of_land_are_wanted_evenly() -> void:
	var town := _two_coloured_town()
	assert_false(town.is_empty(), "seed 12345 has a town on two colours of land")
	var hues: Array = town[1]
	var counts := _wanted(int(town[0]), 2000)
	assert_eq(counts.size(), 2, "only the land's colours")
	for hue in hues:
		assert_almost_eq(float(counts.get(hue, 0)) / 2000.0, 0.5, 0.05, String(hue))


func test_the_amulets_held_do_not_shift_the_draw() -> void:
	# 1997's first 81 passes kept only a held amulet's colour; the 118
	# passes after them overwrote whatever they kept.
	var town := _two_coloured_town()
	var hues: Array = town[1]
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = 0
	player.amulets[String(hues[0])] = 5
	var counts := _wanted(int(town[0]), 2000)
	for hue in hues:
		assert_almost_eq(float(counts.get(hue, 0)) / 2000.0, 0.5, 0.05,
			"%s, with only %s amulets held" % [hue, hues[0]])
