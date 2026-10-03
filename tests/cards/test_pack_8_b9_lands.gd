extends GameTest
## Pack 8 (the Mirage block), batch B9: the lands and mana sources of
## Mirage, Visions and Weatherlight (`cards/sets/<set>/_lands_mana.gd`).
##
## Every claimed card is pinned on its distinguishing rules text, and every
## MANA SOURCE on what the one mana planner (engine/mana_planner.gd — the
## AI's plans and the human double-click auto-cast both) does with it: it
## must pay with the source where the source can pay, and refuse where a
## plan would need a cost the planner may not take on its own (a sacrifice
## of another land, a conversion with nothing to convert, a colour the
## source cannot make).

const DONE := [
	"Sea Scryer", "Quirion Elves", "Charcoal Diamond", "Fire Diamond",
	"Mana Prism", "Marble Diamond", "Moss Diamond", "Sky Diamond",
	"Bad River", "Crystal Vein", "Flood Plain", "Grasslands",
	"Mountain Valley", "Rocky Tar Pit",
	"Squandered Resources", "Sisay's Ring", "Coral Atoll", "Dormant Volcano",
	"Everglades", "Griffin Canyon", "Jungle Basin", "Karoo", "Quicksand",
	"Mind Stone", "Gemstone Mine", "Lotus Vale", "Scorched Ruins",
	"Wall of Roots", "Cadaverous Bloom", "Lion's Eye Diamond",
	"Undiscovered Paradise", "Winding Canyons",
]

const DIAMONDS := {
	"Charcoal Diamond": [Mtg.ManaColor.B, "{B}", "{W}"],
	"Fire Diamond": [Mtg.ManaColor.R, "{R}", "{U}"],
	"Marble Diamond": [Mtg.ManaColor.W, "{W}", "{B}"],
	"Moss Diamond": [Mtg.ManaColor.G, "{G}", "{R}"],
	"Sky Diamond": [Mtg.ManaColor.U, "{U}", "{G}"],
}

## fetch land -> [first basic, second basic, a basic it may NOT fetch]
const FETCHES := {
	"Bad River": ["Island", "Swamp", "Mountain"],
	"Flood Plain": ["Plains", "Island", "Swamp"],
	"Grasslands": ["Forest", "Plains", "Island"],
	"Mountain Valley": ["Mountain", "Forest", "Plains"],
	"Rocky Tar Pit": ["Swamp", "Mountain", "Plains"],
}

## bounce land -> [the basic it returns, its colour, its colour's pip]
const KAROOS := {
	"Coral Atoll": ["Island", Mtg.ManaColor.U, "{U}"],
	"Dormant Volcano": ["Mountain", Mtg.ManaColor.R, "{R}"],
	"Everglades": ["Swamp", Mtg.ManaColor.B, "{B}"],
	"Jungle Basin": ["Forest", Mtg.ManaColor.G, "{G}"],
	"Karoo": ["Plains", Mtg.ManaColor.W, "{W}"],
}


## A seat that answers colour and card questions the way a test says.
class Pick extends DecisionAgent:
	var color := 0
	var decline := false
	var prefer := ""
	func answer_color(_game: MtgGame, _pid: int, _prompt: String, hint: int) -> int:
		return color if color != 0 else hint
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if decline:
			return null
		for c in candidates:
			if c.data.card_name == prefer:
				return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


# ------------------------------------------------------------- helpers --

func _ai_plan(text: String) -> Array:
	return ManaPlanner.plan(g, 0, ManaCost.parse(text), 0)


## The human seat's auto-cast view (the double-click and the castable
## highlight both plan over [method ManaPlanner.auto_tap_sources]).
func _human_plan(text: String) -> Array:
	return ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(g, 0), ManaCost.parse(text), 0)


func _pays(text: String) -> bool:
	return ManaPlanner.plan_and_pay(g, 0, ManaCost.parse(text))


func _pool(color: int) -> int:
	return g.players[0].mana_pool.amount_of(color)


func _mana_index(inst: CardInstance, color: int) -> int:
	for i in inst.cur_mana_abilities.size():
		if int(inst.cur_mana_abilities[i].produces[0][0]) == color:
			return i
	return -1


func _to_library(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst


func _is_pending(card_name: String) -> bool:
	var c := CardRegistry.get_card(card_name)
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


# ------------------------------------------------------------ the pool --

func test_pack_8_alone_keeps_its_pool_and_every_claimed_card_is_complete() -> void:
	assert_eq(CardRegistry.size(), 897 + 621 + 31)
	for card_name in DONE:
		assert_true(CardRegistry.has_card(card_name), card_name)
		assert_false(_is_pending(card_name), card_name)


# ---------------------------------------------------------- Sea Scryer --

func test_sea_scryer_taps_for_colourless_or_turns_one_floating_into_blue() -> void:
	var scryer := put_battlefield(0, "Sea Scryer")
	assert_refused(g.tap_for_mana(0, scryer, 1), "floating")
	assert_false(scryer.tapped, "a refused activation pays nothing")
	assert_ok(g.tap_for_mana(0, scryer, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	g.untap_permanent(scryer)
	assert_ok(g.tap_for_mana(0, scryer, 1))
	assert_eq(_pool(Mtg.ManaColor.C), 0, "the {1} was paid from the floating colourless")
	assert_eq(_pool(Mtg.ManaColor.U), 1)


func test_sea_scryer_planner_needs_another_source_for_the_blue_conversion() -> void:
	var scryer := put_battlefield(0, "Sea Scryer")
	assert_false(_ai_plan("{1}").is_empty())
	assert_true(_ai_plan("{U}").is_empty(), "one Scryer cannot pay its own {1} and tap twice")
	assert_true(_human_plan("{U}").is_empty())
	var forest := put_battlefield(0, "Forest")
	assert_false(_human_plan("{U}").is_empty())
	assert_true(_pays("{U}"))
	assert_true(forest.tapped)
	assert_true(scryer.tapped)
	assert_eq(_pool(Mtg.ManaColor.U), 1)
	assert_eq(_pool(Mtg.ManaColor.G), 0)


func test_sea_scryer_while_summoning_sick_is_no_source() -> void:
	var scryer := put_battlefield(0, "Sea Scryer", true)
	assert_true(_ai_plan("{1}").is_empty())
	assert_refused(g.tap_for_mana(0, scryer, 0), "summoning sickness")


# ------------------------------------------------------- Quirion Elves --

func test_quirion_elves_adds_green_or_the_colour_chosen_as_it_entered() -> void:
	var pick := Pick.new()
	pick.color = Mtg.ManaColor.R
	g.agents[0] = pick
	var elves := put_battlefield(0, "Quirion Elves")
	assert_eq(elves.cur_mana_abilities.size(), 2)
	assert_ok(g.tap_for_mana(0, elves, 1))
	assert_eq(_pool(Mtg.ManaColor.R), 1)
	g.untap_permanent(elves)
	assert_ok(g.tap_for_mana(0, elves, 0))
	assert_eq(_pool(Mtg.ManaColor.G), 1)
	# A second copy chooses for itself.
	pick.color = Mtg.ManaColor.U
	var other := put_battlefield(0, "Quirion Elves")
	assert_ok(g.tap_for_mana(0, other, 1))
	assert_eq(_pool(Mtg.ManaColor.U), 1)
	g.untap_permanent(elves)
	assert_ok(g.tap_for_mana(0, elves, 1))
	assert_eq(_pool(Mtg.ManaColor.R), 2, "the first copy keeps its own choice")


func test_quirion_elves_planner_reads_the_chosen_colour_and_nothing_else() -> void:
	var pick := Pick.new()
	pick.color = Mtg.ManaColor.B
	g.agents[0] = pick
	put_battlefield(0, "Quirion Elves")
	assert_false(_ai_plan("{B}").is_empty())
	assert_false(_ai_plan("{G}").is_empty())
	assert_false(_human_plan("{B}").is_empty())
	assert_true(_ai_plan("{R}").is_empty())
	assert_true(_ai_plan("{B}{G}").is_empty(), "one tap makes one mana")
	assert_true(_pays("{B}"))
	assert_eq(_pool(Mtg.ManaColor.B), 1)


func test_quirion_elves_default_choice_follows_the_hand_it_must_pay_for() -> void:
	give_hand(0, "Hypnotic Specter")   # {1}{B}{B}
	var elves := put_battlefield(0, "Quirion Elves")
	assert_ok(g.tap_for_mana(0, elves, 1))
	assert_eq(_pool(Mtg.ManaColor.B), 1)


func test_quirion_elves_summoning_sick_cannot_tap() -> void:
	var elves := put_battlefield(0, "Quirion Elves", true)
	assert_true(_ai_plan("{G}").is_empty())
	assert_refused(g.tap_for_mana(0, elves, 0), "summoning sickness")


# ------------------------------------------------------------ Diamonds --

func test_the_five_diamonds_enter_tapped_then_make_their_own_colour_only() -> void:
	for card_name in DIAMONDS:
		var row: Array = DIAMONDS[card_name]
		g.players[0].mana_pool.clear()   # floating mana is a source too
		var diamond := put_battlefield(0, card_name)
		assert_true(diamond.tapped, "%s enters tapped" % card_name)
		assert_true(_ai_plan(row[1]).is_empty(), "a tapped %s pays nothing" % card_name)
		g.untap_permanent(diamond)
		assert_false(_ai_plan(row[1]).is_empty(), card_name)
		assert_false(_human_plan(row[1]).is_empty(), card_name)
		assert_true(_ai_plan(row[2]).is_empty(), "%s makes only its colour" % card_name)
		assert_ok(g.tap_for_mana(0, diamond, 0))
		assert_eq(_pool(row[0]), 1, card_name)


func test_a_cast_diamond_arrives_tapped() -> void:
	var diamond := give_hand(0, "Sky Diamond")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, diamond))
	resolve_stack()
	assert_eq(diamond.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(diamond.tapped)


# ---------------------------------------------------------- Mana Prism --

func test_mana_prism_colourless_free_or_any_colour_for_one_more() -> void:
	var prism := put_battlefield(0, "Mana Prism")
	assert_eq(prism.cur_mana_abilities.size(), 6)
	assert_ok(g.tap_for_mana(0, prism, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	g.untap_permanent(prism)
	assert_ok(g.tap_for_mana(0, prism, _mana_index(prism, Mtg.ManaColor.R)))
	assert_eq(_pool(Mtg.ManaColor.C), 0)
	assert_eq(_pool(Mtg.ManaColor.R), 1)
	g.untap_permanent(prism)
	g.players[0].mana_pool.clear()
	assert_refused(g.tap_for_mana(0, prism, _mana_index(prism, Mtg.ManaColor.G)), "floating")
	assert_false(prism.tapped)


func test_mana_prism_planner_converts_only_with_another_source() -> void:
	put_battlefield(0, "Mana Prism")
	assert_false(_ai_plan("{1}").is_empty())
	assert_true(_ai_plan("{R}").is_empty())
	put_battlefield(0, "Forest")
	for text in ["{W}", "{U}", "{B}", "{R}"]:
		assert_false(_ai_plan(text).is_empty(), text)
		assert_false(_human_plan(text).is_empty(), text)
	assert_true(_ai_plan("{W}{U}").is_empty(), "two sources, one conversion")
	assert_true(_pays("{W}"))
	assert_eq(_pool(Mtg.ManaColor.W), 1)


# --------------------------------------------------------- fetch lands --

func test_the_five_fetch_lands_enter_tapped_and_fetch_either_basic_untapped() -> void:
	for card_name in FETCHES:
		var row: Array = FETCHES[card_name]
		g.players[0].library.clear()
		var wrong := _to_library(0, row[2])
		var second := _to_library(0, row[1])
		var fetch := put_battlefield(0, card_name)
		assert_true(fetch.tapped, "%s enters tapped" % card_name)
		assert_refused(g.activate_ability(0, fetch, 0))
		g.untap_permanent(fetch)
		assert_ok(g.activate_ability(0, fetch, 0))
		assert_eq(fetch.zone, Mtg.Zone.GRAVEYARD, "%s is sacrificed as a cost" % card_name)
		resolve_stack()
		assert_eq(second.zone, Mtg.Zone.BATTLEFIELD, card_name)
		assert_false(second.tapped, "%s's land arrives untapped" % card_name)
		assert_eq(wrong.zone, Mtg.Zone.LIBRARY, card_name)
		var first := _to_library(0, row[0])
		var again := put_battlefield(0, card_name)
		g.untap_permanent(again)
		assert_ok(g.activate_ability(0, again, 0))
		resolve_stack()
		assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, card_name)
		assert_eq(wrong.zone, Mtg.Zone.LIBRARY, card_name)


func test_bad_river_finds_a_nonbasic_island_or_swamp_card() -> void:
	g.players[0].library.clear()
	var sea := _to_library(0, "Underground Sea")
	var river := put_battlefield(0, "Bad River")
	g.untap_permanent(river)
	assert_ok(g.activate_ability(0, river, 0))
	resolve_stack()
	assert_eq(sea.zone, Mtg.Zone.BATTLEFIELD)


func test_a_fetch_land_makes_no_mana_and_finds_nothing_in_the_wrong_library() -> void:
	var plain := put_battlefield(0, "Flood Plain")
	g.untap_permanent(plain)
	assert_true(plain.cur_mana_abilities.is_empty())
	assert_true(_ai_plan("{1}").is_empty())
	var library := g.players[0].library.size()   # thirty Forests
	assert_ok(g.activate_ability(0, plain, 0))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library, "no Plains or Island card: nothing is found")
	assert_eq(plain.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Crystal Vein --

func test_crystal_vein_taps_for_one_or_sacrifices_for_two() -> void:
	var vein := put_battlefield(0, "Crystal Vein")
	assert_ok(g.tap_for_mana(0, vein, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	assert_eq(vein.zone, Mtg.Zone.BATTLEFIELD)
	g.untap_permanent(vein)
	assert_ok(g.tap_for_mana(0, vein, 1))
	assert_eq(_pool(Mtg.ManaColor.C), 3)
	assert_eq(vein.zone, Mtg.Zone.GRAVEYARD)


func test_crystal_vein_planner_never_sacrifices_it_for_what_a_tap_pays() -> void:
	var vein := put_battlefield(0, "Crystal Vein")
	assert_false(_human_plan("{1}").is_empty())
	assert_true(_ai_plan("{3}").is_empty())
	assert_true(_ai_plan("{W}").is_empty())
	assert_true(_pays("{1}"))
	assert_eq(vein.zone, Mtg.Zone.BATTLEFIELD, "the plain tap pays {1}; the sacrifice is kept")
	assert_true(vein.tapped)
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	var other := put_battlefield(0, "Crystal Vein")
	put_battlefield(0, "Forest")
	g.players[0].mana_pool.clear()
	assert_true(_pays("{1}{G}"))
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD)


## The planner reaches an instance's higher-yield row (the Vein's
## sacrifice) once the generic pass runs short — and only then.
func test_crystal_vein_planner_sacrifices_it_when_the_cost_needs_two() -> void:
	var vein := put_battlefield(0, "Crystal Vein")
	assert_true(_ai_plan("{3}").is_empty())
	assert_false(_ai_plan("{2}").is_empty())
	assert_false(_human_plan("{2}").is_empty())
	assert_true(_pays("{2}"))
	assert_eq(vein.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pool(Mtg.ManaColor.C), 2)
	var other := put_battlefield(0, "Crystal Vein")
	put_battlefield(0, "Forest")
	g.players[0].mana_pool.clear()
	assert_false(_ai_plan("{3}").is_empty())
	assert_false(_human_plan("{3}").is_empty())
	assert_true(_ai_plan("{4}").is_empty())
	assert_true(_pays("{3}"), "Forest's one and the Vein's two")
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------- Squandered Resources --

func test_squandered_resources_sacrifices_a_land_for_a_type_it_could_produce() -> void:
	var resources := put_battlefield(0, "Squandered Resources")
	var sea := put_battlefield(0, "Underground Sea")
	var pick := Pick.new()
	pick.color = Mtg.ManaColor.B
	g.agents[0] = pick
	assert_ok(g.tap_for_mana(0, sea, _mana_index(sea, Mtg.ManaColor.U)))
	assert_ok(g.tap_for_mana(0, resources, 0))   # a tapped land can still be sacrificed
	assert_eq(sea.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pool(Mtg.ManaColor.U), 1)
	assert_eq(_pool(Mtg.ManaColor.B), 1, "any type the sacrificed land could produce")
	assert_false(resources.tapped, "no {T} in the cost")
	assert_refused(g.tap_for_mana(0, resources, 0))
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, resources, 0))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pool(Mtg.ManaColor.G), 1, "a Forest offers only green")


func test_squandered_resources_gets_nothing_from_a_land_that_makes_no_mana() -> void:
	var resources := put_battlefield(0, "Squandered Resources")
	var maze := put_battlefield(0, "Maze of Ith")
	assert_ok(g.tap_for_mana(0, resources, 0))
	assert_eq(maze.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_squandered_resources_is_never_planned() -> void:
	put_battlefield(0, "Squandered Resources")
	var forest := put_battlefield(0, "Forest")
	assert_false(_ai_plan("{G}").is_empty())
	assert_true(_ai_plan("{G}{G}").is_empty(), "eating a land is never an implicit auto-tap")
	assert_true(_human_plan("{1}{G}").is_empty())
	assert_true(_pays("{G}"))
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Sisay's Ring --

func test_sisays_ring_taps_for_two_colourless() -> void:
	var ring := put_battlefield(0, "Sisay's Ring")
	assert_false(_ai_plan("{2}").is_empty())
	assert_true(_ai_plan("{3}").is_empty())
	assert_true(_ai_plan("{G}").is_empty())
	assert_ok(g.tap_for_mana(0, ring, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 2)
	var bear := give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	g.untap_permanent(ring)
	g.players[0].mana_pool.clear()
	assert_true(_pays("{1}{G}"))
	assert_ok(g.cast_spell(0, bear))


# ----------------------------------------------------------- bounce lands --

func test_the_five_bounce_lands_return_an_untapped_basic_and_tap_for_two() -> void:
	for card_name in KAROOS:
		var row: Array = KAROOS[card_name]
		var basic := put_battlefield(0, row[0])
		var land := put_battlefield(0, card_name)
		resolve_stack()
		assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, card_name)
		assert_true(land.tapped, "%s enters tapped" % card_name)
		assert_eq(basic.zone, Mtg.Zone.HAND, "%s returns its %s" % [card_name, row[0]])
		assert_true(_ai_plan("{1}" + row[2]).is_empty(), "tapped: nothing to plan")
		g.untap_permanent(land)
		assert_false(_ai_plan("{1}" + row[2]).is_empty(), card_name)
		assert_false(_human_plan("{1}" + row[2]).is_empty(), card_name)
		assert_true(_ai_plan(row[2] + row[2]).is_empty(), "%s makes one coloured mana" % card_name)
		g.players[0].mana_pool.clear()
		assert_ok(g.tap_for_mana(0, land, 0))
		assert_eq(_pool(Mtg.ManaColor.C), 1, card_name)
		assert_eq(_pool(row[1]), 1, card_name)


func test_karoo_without_an_untapped_plains_is_sacrificed() -> void:
	var plains := put_battlefield(0, "Plains")
	g.tap_permanent(plains)
	put_battlefield(0, "Island")
	var karoo := give_hand(0, "Karoo")
	assert_ok(g.play_land(0, karoo))
	resolve_stack()
	assert_eq(karoo.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)


func test_coral_atoll_may_decline_and_is_then_sacrificed() -> void:
	var island := put_battlefield(0, "Island")
	var pick := Pick.new()
	pick.decline = true
	g.agents[0] = pick
	var atoll := put_battlefield(0, "Coral Atoll")
	resolve_stack()
	assert_eq(atoll.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)


func test_everglades_returns_a_nonbasic_swamp_too() -> void:
	var sea := put_battlefield(0, "Underground Sea")
	var glades := put_battlefield(0, "Everglades")
	resolve_stack()
	assert_eq(glades.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(sea.zone, Mtg.Zone.HAND)


func test_a_bounce_land_gone_before_its_trigger_resolves_asks_nothing() -> void:
	var forest := put_battlefield(0, "Forest")
	var basin := put_battlefield(0, "Jungle Basin")
	g.return_to_hand(basin)
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(basin.zone, Mtg.Zone.HAND)


# -------------------------------------------------------- Griffin Canyon --

func test_griffin_canyon_untaps_a_griffin_and_pumps_it_while_a_creature() -> void:
	var canyon := put_battlefield(0, "Griffin Canyon")
	var griffin := put_battlefield(1, "Ekundu Griffin")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(griffin)
	assert_refused(g.activate_ability(0, canyon, 0, [TargetRef.card(bear)]))
	assert_false(canyon.tapped)
	assert_ok(g.activate_ability(0, canyon, 0, [TargetRef.card(griffin)]))
	resolve_stack()
	assert_false(griffin.tapped, "any player's Griffin")
	assert_eq(griffin.cur_power, 3)
	assert_eq(griffin.cur_toughness, 3)
	advance_to_next_turn()
	assert_eq(griffin.cur_power, 2, "until end of turn")


func test_griffin_canyon_taps_for_colourless() -> void:
	var canyon := put_battlefield(0, "Griffin Canyon")
	assert_false(_ai_plan("{1}").is_empty())
	assert_true(_ai_plan("{W}").is_empty())
	assert_ok(g.tap_for_mana(0, canyon, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)


# ------------------------------------------------------------- Quicksand --

func test_quicksand_shrinks_an_attacker_without_flying() -> void:
	var sand := put_battlefield(0, "Quicksand")
	assert_false(_ai_plan("{1}").is_empty())
	advance_to_next_turn()
	var bear := put_battlefield(1, "Grizzly Bears")
	var griffin := put_battlefield(1, "Ekundu Griffin")
	var idle := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id, griffin.id]))
	if g.priority_player != 0: assert_ok(g.pass_priority(g.priority_player))
	assert_refused(g.activate_ability(0, sand, 0, [TargetRef.card(griffin)]))
	assert_refused(g.activate_ability(0, sand, 0, [TargetRef.card(idle)]))
	assert_eq(sand.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.activate_ability(0, sand, 0, [TargetRef.card(bear)]))
	assert_eq(sand.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "2/2 at -1/-2 is 1/0")


# ------------------------------------------------------------ Mind Stone --

func test_mind_stone_taps_for_one_or_cashes_in_for_a_card() -> void:
	var stone := put_battlefield(0, "Mind Stone")
	assert_false(_ai_plan("{1}").is_empty())
	assert_refused(g.activate_ability(0, stone, 0))
	assert_eq(stone.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, Mtg.ManaColor.G)
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, stone, 0))
	assert_eq(stone.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_mind_stone_taps_for_colourless() -> void:
	var stone := put_battlefield(0, "Mind Stone")
	assert_ok(g.tap_for_mana(0, stone, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	assert_refused(g.activate_ability(0, stone, 0), "tapped")


# --------------------------------------------------------- Gemstone Mine --

func test_gemstone_mine_mines_three_colours_then_is_sacrificed() -> void:
	var mine := put_battlefield(0, "Gemstone Mine")
	assert_eq(int(mine.counters.get("mining", 0)), 3)
	assert_eq(mine.cur_mana_abilities.size(), 5)
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B]:
		g.untap_permanent(mine)
		assert_ok(g.tap_for_mana(0, mine, _mana_index(mine, color)))
		assert_eq(_pool(color), 1)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the last counter gone: sacrificed")


func test_gemstone_mine_planner_pays_any_one_colour_while_it_has_counters() -> void:
	var mine := put_battlefield(0, "Gemstone Mine")
	for text in ["{W}", "{U}", "{B}", "{R}", "{G}", "{1}"]:
		assert_false(_ai_plan(text).is_empty(), text)
		assert_false(_human_plan(text).is_empty(), text)
	assert_true(_ai_plan("{R}{G}").is_empty())
	assert_true(_pays("{R}"))
	assert_eq(int(mine.counters.get("mining", 0)), 2)
	assert_eq(_pool(Mtg.ManaColor.R), 1)


func test_gemstone_mine_without_counters_cannot_be_tapped() -> void:
	var mine := put_battlefield(0, "Gemstone Mine")
	g.remove_counters(mine, "mining", 3)
	assert_true(_ai_plan("{1}").is_empty())
	assert_refused(g.tap_for_mana(0, mine, 0), "counter")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------- Lotus Vale, Scorched Ruins --

func test_lotus_vale_eats_two_untapped_lands_then_makes_three_of_one_colour() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var island := put_battlefield(0, "Island")
	g.tap_permanent(island)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(vale.tapped)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD, "a tapped land cannot be fed")
	assert_eq(vale.cur_mana_abilities.size(), 5)
	assert_ok(g.tap_for_mana(0, vale, _mana_index(vale, Mtg.ManaColor.R)))
	assert_eq(_pool(Mtg.ManaColor.R), 3)


func test_lotus_vale_without_two_untapped_lands_goes_to_the_graveyard() -> void:
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(0, "Island")
	g.tap_permanent(island)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_lotus_vale_may_decline_and_keeps_both_lands() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var pick := Pick.new()
	pick.decline = true
	g.agents[0] = pick
	var vale := put_battlefield(0, "Lotus Vale")
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)


func test_lotus_vale_planner_pays_three_of_one_colour_never_two_colours() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var vale := put_battlefield(0, "Lotus Vale")
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(_ai_plan("{G}{G}{G}").is_empty())
	assert_false(_human_plan("{B}{B}{B}").is_empty())
	assert_false(_ai_plan("{1}{U}{U}").is_empty())
	assert_true(_ai_plan("{R}{G}").is_empty(), "three of ONE colour")
	assert_true(_ai_plan("{4}").is_empty())
	var bear := give_hand(0, "Grizzly Bears")
	assert_true(_pays("{1}{G}"))
	assert_ok(g.cast_spell(0, bear))
	assert_eq(_pool(Mtg.ManaColor.G), 1, "the third green floats")


func test_scorched_ruins_eats_two_untapped_lands_and_taps_for_four() -> void:
	var a := put_battlefield(0, "Mountain")
	var b := put_battlefield(0, "Swamp")
	var ruins := put_battlefield(0, "Scorched Ruins")
	assert_eq(ruins.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_false(_ai_plan("{4}").is_empty())
	assert_true(_ai_plan("{5}").is_empty())
	assert_true(_ai_plan("{R}").is_empty(), "colourless only")
	assert_ok(g.tap_for_mana(0, ruins, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 4)


func test_scorched_ruins_alone_is_buried() -> void:
	var ruins := give_hand(0, "Scorched Ruins")
	assert_ok(g.play_land(0, ruins))
	assert_eq(ruins.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Wall of Roots --

func test_wall_of_roots_shrinks_for_green_once_each_turn_sick_or_tapped() -> void:
	var wall := put_battlefield(0, "Wall of Roots", true)
	assert_false(_ai_plan("{G}").is_empty(), "no {T}: summoning sickness is no bar")
	assert_ok(g.tap_for_mana(0, wall, 0))
	assert_eq(_pool(Mtg.ManaColor.G), 1)
	assert_false(wall.tapped)
	assert_eq(int(wall.counters.get("-0/-1", 0)), 1)
	assert_eq(wall.cur_toughness, 4)
	g.players[0].mana_pool.clear()
	assert_refused(g.tap_for_mana(0, wall, 0))
	assert_true(_ai_plan("{G}").is_empty(), "spent for this turn")
	assert_eq(int(wall.counters.get("-0/-1", 0)), 1, "a refused activation puts no counter")
	advance_to_next_turn()   # the opponent's turn: "each turn", not "your turn"
	g.tap_permanent(wall)
	assert_false(_human_plan("{G}").is_empty(), "a tapped Wall still pays")
	assert_true(_pays("{G}"))
	assert_eq(int(wall.counters.get("-0/-1", 0)), 2)
	assert_eq(wall.cur_toughness, 3)


func test_wall_of_roots_the_planner_never_kills_it_but_a_player_may() -> void:
	var wall := put_battlefield(0, "Wall of Roots")
	g.add_counters(wall, "-0/-1", 4)
	assert_eq(wall.cur_toughness, 1)
	assert_true(_ai_plan("{G}").is_empty(), "the counter would kill it")
	assert_true(_human_plan("{1}").is_empty())
	assert_ok(g.tap_for_mana(0, wall, 0))
	assert_eq(_pool(Mtg.ManaColor.G), 1, "the mana is made even though the cost kills it")
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------ Cadaverous Bloom --

func test_cadaverous_bloom_exiles_a_card_from_hand_for_two_black_or_two_green() -> void:
	var bloom := put_battlefield(0, "Cadaverous Bloom")
	assert_refused(g.tap_for_mana(0, bloom, 0))
	var pick := Pick.new()
	pick.prefer = "Forest"
	g.agents[0] = pick
	var bear := give_hand(0, "Grizzly Bears")
	var forest := give_hand(0, "Forest")
	assert_ok(g.tap_for_mana(0, bloom, _mana_index(bloom, Mtg.ManaColor.B)))
	assert_eq(_pool(Mtg.ManaColor.B), 2)
	assert_eq(forest.zone, Mtg.Zone.EXILE, "the payer chose which card")
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_false(bloom.tapped)
	assert_ok(g.tap_for_mana(0, bloom, _mana_index(bloom, Mtg.ManaColor.G)))
	assert_eq(_pool(Mtg.ManaColor.G), 2)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_refused(g.tap_for_mana(0, bloom, 0))


func test_cadaverous_bloom_is_never_planned() -> void:
	put_battlefield(0, "Cadaverous Bloom")
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Forest")
	assert_true(_ai_plan("{B}").is_empty(), "exiling a card is never an implicit auto-tap")
	assert_true(_human_plan("{G}{G}").is_empty())
	assert_false(_pays("{1}"))
	assert_eq(g.players[0].hand.size(), 2)


# ---------------------------------------------------- Lion's Eye Diamond --

func test_lions_eye_diamond_discards_the_hand_and_sacrifices_for_three_of_a_colour() -> void:
	var led := put_battlefield(0, "Lion's Eye Diamond")
	var bear := give_hand(0, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_eq(led.cur_mana_abilities.size(), 5)
	assert_ok(g.tap_for_mana(0, led, _mana_index(led, Mtg.ManaColor.R)))
	assert_eq(_pool(Mtg.ManaColor.R), 3)
	assert_eq(led.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].hand.is_empty())


func test_lions_eye_diamond_pays_with_an_empty_hand() -> void:
	var led := put_battlefield(0, "Lion's Eye Diamond", true)
	assert_ok(g.tap_for_mana(0, led, _mana_index(led, Mtg.ManaColor.U)))
	assert_eq(_pool(Mtg.ManaColor.U), 3)


func test_lions_eye_diamond_only_as_an_instant_and_never_planned() -> void:
	var led := put_battlefield(0, "Lion's Eye Diamond")
	give_hand(0, "Grizzly Bears")
	assert_true(_ai_plan("{1}").is_empty())
	assert_true(_human_plan("{B}").is_empty())
	assert_false(_pays("{1}"))
	assert_eq(led.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_refused(g.tap_for_mana(0, led, 0))
	assert_eq(led.zone, Mtg.Zone.BATTLEFIELD, "a refused activation pays nothing")
	assert_eq(g.players[0].hand.size(), 1)


# ------------------------------------------------- Undiscovered Paradise --

func test_undiscovered_paradise_any_colour_then_home_in_your_next_untap_step() -> void:
	var paradise := put_battlefield(0, "Undiscovered Paradise")
	assert_eq(paradise.cur_mana_abilities.size(), 5)
	assert_ok(g.tap_for_mana(0, paradise, _mana_index(paradise, Mtg.ManaColor.B)))
	assert_eq(_pool(Mtg.ManaColor.B), 1)
	advance_to_next_turn()   # the opponent's untap step is not "your"
	assert_eq(paradise.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(paradise.tapped)
	advance_to_next_turn()
	assert_eq(paradise.zone, Mtg.Zone.HAND)


func test_undiscovered_paradise_left_untapped_stays() -> void:
	var paradise := put_battlefield(0, "Undiscovered Paradise")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(paradise.zone, Mtg.Zone.BATTLEFIELD)


func test_undiscovered_paradise_bounce_does_not_follow_a_new_object() -> void:
	var paradise := put_battlefield(0, "Undiscovered Paradise")
	assert_ok(g.tap_for_mana(0, paradise, 0))
	g.return_to_hand(paradise)
	g.put_from_hand_into_play(paradise, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(paradise.zone, Mtg.Zone.BATTLEFIELD, "CR 400.7: the land that returned is a new object")


func test_undiscovered_paradise_planner_pays_any_one_colour_and_it_still_returns() -> void:
	var paradise := put_battlefield(0, "Undiscovered Paradise")
	for text in ["{W}", "{U}", "{B}", "{R}", "{G}", "{1}"]:
		assert_false(_ai_plan(text).is_empty(), text)
		assert_false(_human_plan(text).is_empty(), text)
	assert_true(_ai_plan("{W}{U}").is_empty())
	assert_true(_pays("{G}"))
	assert_eq(_pool(Mtg.ManaColor.G), 1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(paradise.zone, Mtg.Zone.HAND)


# ------------------------------------------------------- Winding Canyons --

func test_winding_canyons_lets_creatures_be_cast_as_though_they_had_flash() -> void:
	var canyons := put_battlefield(0, "Winding Canyons")
	assert_false(_ai_plan("{1}").is_empty())
	assert_true(_ai_plan("{G}").is_empty())
	advance_to_next_turn()   # the opponent's turn
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var bear := give_hand(0, "Grizzly Bears")
	var tutor := give_hand(0, "Demonic Tutor")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, canyons, 0))
	assert_true(canyons.tapped)
	resolve_stack()
	if g.priority_player != 0: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, 0)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, tutor))
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_winding_canyons_permission_lasts_only_this_turn() -> void:
	var canyons := put_battlefield(0, "Winding Canyons")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, canyons, 0))
	resolve_stack()
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear))
	assert_eq(bear.zone, Mtg.Zone.HAND)
