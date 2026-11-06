extends GameTest
## Pack 10 (the Urza block), batch B8: the AI metadata and hints the
## artifacts declare reach the fair AI. Mishra's Helix carries the
## `tap_x_lands` role and Braidwood Sextant `land_search`
## (engine/ai/alliances_tactics.gd): with the gate off (the null arm) the
## pilot is as it was. The card-local hints — Phyrexian Processor's life,
## Scrying Glass's colour, Urza's Incubator's type, Memory Jar's use —
## read public state and the chooser's own cards only: a different hidden
## opponent hand never moves them, a public change does (docs/fair-play.md).

const U := preload("res://cards/sets/usg/_artifacts.gd")
const D := preload("res://cards/sets/uds/_artifacts.gd")

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai

## P1's upkeep with an empty stack, P1 having passed: P0 holds priority.
func _their_upkeep_our_priority() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	resolve_stack()
	assert_eq(g.priority_player, 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------- Mishra's Helix: tap_x_lands --

func _helix_board() -> Array[CardInstance]:
	put_battlefield(0, "Mishra's Helix")
	for _n in 3: put_battlefield(0, "Island")
	var lands: Array[CardInstance] = [put_battlefield(1, "Forest"), put_battlefield(1, "Forest")]
	return lands

func test_the_ai_helix_taps_the_opponents_lands_in_their_upkeep() -> void:
	var ai := _ai()
	var lands := _helix_board()
	_their_upkeep_our_priority()
	assert_eq(ai.act(g), "activated Mishra's Helix")
	resolve_stack()
	assert_true(lands[0].tapped and lands[1].tapped)

func test_the_null_arm_leaves_the_helix_alone() -> void:
	var ai := _ai(false)
	_helix_board()
	_their_upkeep_our_priority()
	assert_ne(ai.act(g), "activated Mishra's Helix")


# --------------------------------------------- Braidwood Sextant: land_search --

func test_the_ai_cracks_its_sextant_for_a_land() -> void:
	var ai := _ai()
	put_battlefield(0, "Braidwood Sextant")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	assert_eq(ai.act(g), "activated Braidwood Sextant")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)

func test_the_null_arm_keeps_the_sextant() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Braidwood Sextant")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	assert_ne(ai.act(g), "activated Braidwood Sextant")


# ---------------------------------------------------- Phyrexian Processor hint --

func _processor_paid(hidden: Array, their_creatures: Array) -> int:
	before_each()
	_ai()
	for card_name in hidden: give_hand(1, card_name)
	for card_name in their_creatures: put_battlefield(1, card_name)
	var processor := give_hand(0, "Phyrexian Processor")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, processor))
	resolve_stack()
	return int(processor.memory.get("paid", -1))

func test_the_processor_hint_keeps_a_floor_above_the_visible_threat() -> void:
	assert_eq(_processor_paid([], []), 10, "half its life with nothing in sight")
	assert_eq(_processor_paid([], ["Grizzly Bears", "Grizzly Bears"]), 7, "20 - (5 + 2 x 4)")
	assert_eq(_processor_paid([], ["Shivan Dragon", "Hill Giant"]), 0, "nothing to spare under 8 power")

func test_the_processor_hint_ignores_the_opponents_hidden_hand() -> void:
	var a := _processor_paid(["Lightning Bolt", "Fireball"], ["Grizzly Bears"])
	var b := _processor_paid(["Forest", "Island"], ["Grizzly Bears"])
	assert_eq(a, b)


# ------------------------------------------------------ Scrying Glass's guess --

func test_the_glass_colour_hint_reads_public_zones_only() -> void:
	give_hand(1, "Counterspell")
	give_hand(1, "Counterspell")
	put_battlefield(1, "Hill Giant")
	assert_eq(D.glass_color_hint(g, 1), Mtg.ManaColor.R, "the red creature they show, not the blue hand")
	g.players[1].hand.clear()
	give_hand(1, "Lightning Bolt")
	assert_eq(D.glass_color_hint(g, 1), Mtg.ManaColor.R, "a different hidden hand, the same guess")
	put_battlefield(1, "Llanowar Elves")
	put_battlefield(1, "Llanowar Elves")
	assert_eq(D.glass_color_hint(g, 1), Mtg.ManaColor.G, "a public change moves it")


# ------------------------------------------------------ Urza's Incubator's type --

func test_the_incubator_hint_names_the_choosers_own_tribe() -> void:
	g.players[0].deck_names.append_array(["Goblin King", "Goblin King", "Grizzly Bears"])
	g.players[1].deck_names.append_array(["Llanowar Elves", "Llanowar Elves", "Llanowar Elves"])
	give_hand(1, "Llanowar Elves")
	var hint := D.incubator_hint(g, 0)
	assert_eq(D.TYPES.ALL[hint], "Goblin", "its own deck, never the opponent's")


# --------------------------------------------------- Smokestack / Umbilicus hints --

func test_the_soot_hint_counts_public_permanents() -> void:
	var stack := put_battlefield(0, "Smokestack")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")
	assert_false(U.soot_hint(g, stack, 0), "even: no soot")
	put_battlefield(0, "Forest")
	assert_true(U.soot_hint(g, stack, 0), "more permanents than the opponent: soot")
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	assert_true(U.soot_hint(g, stack, 0), "the opponent's hidden hand changes nothing")


# ------------------------------------------------------------------ Memory Jar --

## The pilot's use of Memory Jar reads hand SIZES only: two opponent hands
## of the same size with different cards give the same answer.
func test_the_memory_jar_answer_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in [["Lightning Bolt", "Counterspell"], ["Forest", "Island"]]:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Memory Jar")
		for card_name in filler: give_hand(1, card_name)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
