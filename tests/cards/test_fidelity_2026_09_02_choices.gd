extends GameTest
## The choice-funnel lifts of the 2026-09-02 fidelity pass — rows whose
## whole deviation was an engine-made choice: Erosion's "{1} or 1 life",
## Twiddle's "tap or untap", WHICH Tetravites Tetravus absorbs, WHICH
## Forests Wood Elemental eats, Natural Selection's order (and its shuffle),
## the mana batteries' "any number" of counters, Mana Flare's "any type
## that land produced", the word pairs of Magical Hack and Sleight of Mind,
## and Worms of the Earth's "any player" escape. Each is pinned on what the
## row denied it: a seat that answers what the old heuristic never would,
## and gets it. The 1997 prompts are cited beside the seat that reads them.


## A seat that answers by script: OPTION questions by label, CARD questions
## by instance id (-1 declines), and records everything it was asked.
class Seat extends DecisionAgent:
	var labels: Array = []      # OPTION answers, in order (by label)
	var cards: Array = []       # CARD answers, in order (instance ids; -1 = null)
	var yes := true
	var asked: Array = []       # [prompt, options] per OPTION question
	var offered: Array = []     # [prompt, [ids]] per CARD question
	var yes_no_prompts: Array = []

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append([prompt, options.duplicate()])
		if labels.is_empty():
			return hint
		var wanted := String(labels.pop_front())
		var at := options.find(wanted)
		return at if at >= 0 else hint

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		var ids: Array = []
		for inst in candidates:
			ids.append(inst.id)
		offered.append([prompt, ids])
		if cards.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want := int(cards.pop_front())
		if want == -1:
			return null
		for inst in candidates:
			if inst.id == want:
				return inst
		return null if candidates.is_empty() else candidates[0]

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			_hint: bool) -> bool:
		yes_no_prompts.append(prompt)
		return yes


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


func _seat(pid: int) -> Seat:
	var seat := Seat.new()
	g.set_agent(pid, seat)
	return seat


# ------------------------------------------------------------------ Erosion --
#
# `@EROSION` (Program/prompts.txt:306): "Select target land." / "Destroy
# enchanted land." / "Pay 1 mana to counter." / "Pay 1 life." — the three
# answers are the original's own lines, and the VICTIM gives one.

const EROSION_WAYS := ["Destroy enchanted land.", "Pay 1 mana to counter.", "Pay 1 life."]


func _erode_their_forest() -> CardInstance:
	var forest := put_battlefield(1, "Forest")
	var erosion := give_hand(0, "Erosion")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, erosion, [TargetRef.card(forest)]))
	resolve_stack()
	return forest


func test_erosion_lets_the_victim_pay_life_while_holding_mana() -> void:
	var forest := _erode_their_forest()
	var seat := _seat(1)
	seat.labels = ["Pay 1 life."]
	advance_to_next_turn()       # their upkeep: the toll comes due
	assert_eq(seat.asked.size(), 1, "one question, to the land's controller")
	assert_eq(seat.asked[0][1], EROSION_WAYS, "the original's three lines")
	assert_eq(g.players[1].life, 19, "1 life, as they chose")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(forest.tapped, "and the land was NOT tapped for the {1}")


func test_erosion_lets_the_victim_give_the_land_up() -> void:
	var forest := _erode_their_forest()
	var seat := _seat(1)
	seat.labels = ["Destroy enchanted land."]
	advance_to_next_turn()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "they let it go")
	assert_eq(g.players[1].life, 20, "and paid nothing else")


func test_erosion_hint_pays_mana_when_it_can_and_life_when_it_cannot() -> void:
	var forest := _erode_their_forest()
	var seat := _seat(1)
	advance_to_next_turn()       # {1} affordable: the Forest taps for it
	assert_true(forest.tapped)
	assert_eq(g.players[1].life, 20)
	assert_eq(seat.asked[0][0], "Erosion: destroy the land unless you pay {1} or 1 life?")
	# Tapped when the toll comes due again (the trigger is on the stack,
	# the land goes down in response): no mana, so the hint pays the life.
	advance_to_next_turn()       # our turn 3
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 1)
	assert_eq(g.stack.size(), 1)
	g.tap_permanent(forest)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "no mana: the hint pays a life")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)


func test_erosion_at_one_life_hint_gives_up_the_land() -> void:
	# With no mana and 1 life the heuristic lets the land go rather than
	# pay its last life; the option itself stays on the list (CR 119.4 —
	# a player may pay life equal to their total).
	var forest := _erode_their_forest()
	var seat := _seat(1)
	g.players[1].life = 1
	advance_to_step(Mtg.Step.END)
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 1)
	g.tap_permanent(forest)      # in response: it cannot make the {1}
	resolve_stack()
	assert_eq(seat.asked[0][1], EROSION_WAYS, "all three ways, life included")
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the hint gives up the land")
	assert_eq(g.players[1].life, 1)


# ------------------------------------------------------------------ Twiddle --
#
# `@TWIDDLE` (Program/prompts.txt:920): "Select target creature, artifact
# or land." / "Tap." / "Untap." — the mode is asked on resolution.

func test_twiddle_offers_tap_and_untap_and_honours_a_redundant_pick() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(bear)
	var seat := _seat(0)
	seat.labels = ["Tap."]
	var twiddle := give_hand(0, "Twiddle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, twiddle, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(seat.asked[0][1], ["Tap.", "Untap."], "the original's two lines")
	assert_true(bear.tapped, "'Tap.' on a tapped creature does nothing — as printed")


func test_twiddle_hint_is_the_mode_that_does_something() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var seat := _seat(0)
	var twiddle := give_hand(0, "Twiddle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, twiddle, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.tapped, "untapped target: the hint taps it")
	assert_eq(seat.asked[0][1][0], "Tap.")
	var again := give_hand(0, "Twiddle")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, again, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped, "tapped target: the hint untaps it")


# ----------------------------------------------------------------- Tetravus --
#
# `@TETRAVUS` (Program/prompts.txt:890): "Launch tetravite." / "Dock
# tetravite." / "Never mind." / "Move 1 token." ... — the original asked
# WHICH token to dock; here the count is asked and then each body.

func _tetravites_of(pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == "Tetravite":
			out.append(inst)
	return out


func test_tetravus_absorbs_the_tetravite_its_controller_names() -> void:
	var tet := put_battlefield(0, "Tetravus")
	advance_to_next_turn()
	advance_to_next_turn()       # our upkeep: the hint buds all three
	var brood := _tetravites_of(0)
	assert_eq(brood.size(), 3)
	var stray := brood[0]
	var kept := brood[1]
	g.change_control(stray, 1)
	var seat := _seat(0)
	# The absorb resolves first (last on the stack), then the bud offers to
	# spend the counter it just earned: "1" body, then "0" counters out.
	seat.labels = ["1", "0"]
	seat.cards = [kept.id]       # our OWN one, not the stray the hint would take
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(kept.zone, Mtg.Zone.EXILE, "the one we named")
	assert_eq(stray.zone, Mtg.Zone.BATTLEFIELD, "the stray stays with them")
	assert_eq(stray.controller_id, 1)
	assert_eq(int(tet.counters.get("+1/+1", 0)), 1, "kept, the bud declined")
	assert_eq(seat.offered.size(), 1)
	assert_eq(seat.offered[0][1][0], stray.id, "listed strays first — the hint")
	assert_eq(seat.offered[0][1].size(), 3, "every Tetravite it made was on the list")


func test_tetravus_hint_still_takes_the_stray_first() -> void:
	put_battlefield(0, "Tetravus")
	advance_to_next_turn()
	advance_to_next_turn()
	var stray := _tetravites_of(0)[0]
	g.change_control(stray, 1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(stray.zone, Mtg.Zone.EXILE, "absorbed, wherever it was")
	assert_eq(_tetravites_of(1).size(), 0)


# ----------------------------------------------------------- Wood Elemental --
#
# `@SACRIFICE_X_BASICLAND` (Program/promptsX2.txt:117) entry 3 is the
# original's line for a Forest: "Select forest to sacrifice."

func test_wood_elemental_eats_the_forests_its_controller_names() -> void:
	var a := put_battlefield(0, "Forest")
	var b := put_battlefield(0, "Forest")
	var c := put_battlefield(0, "Forest")
	var seat := _seat(0)
	seat.labels = ["2"]
	seat.cards = [c.id, a.id]
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_eq(elemental.cur_power, 2)
	assert_eq(elemental.cur_toughness, 2)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(c.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.BATTLEFIELD, "the one it did not name stands")
	assert_eq(seat.offered.size(), 2, "one pick per Forest")
	assert_eq(seat.offered[0][0], "Select forest to sacrifice.")
	assert_eq(seat.offered[1][1].size(), 2, "the second pick no longer lists the first")


func test_wood_elemental_hint_spares_a_forest_with_an_aura() -> void:
	var loved := put_battlefield(0, "Forest")
	g.attach_aura_from_anywhere(give_hand(0, "Wild Growth"), loved, 0)
	var loose := put_battlefield(0, "Forest")
	var seat := _seat(0)
	seat.labels = ["1"]
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_eq(elemental.cur_power, 1)
	assert_eq(loose.zone, Mtg.Zone.GRAVEYARD, "the bare Forest is first on the list")
	assert_eq(loved.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(seat.offered[0][1][0], loose.id)


# -------------------------------------------------------- Natural Selection --
#
# `@NATURAL_SELECTION` (Program/promptsX1.txt:274): "Select target player."
# / "Select card order or DONE to shuffle." — the cards are named top
# first, and declining is the shuffle.

func _stack_their_top(names: Array) -> Array[CardInstance]:
	# names[0] ends on TOP.
	var out: Array[CardInstance] = []
	for i in range(names.size() - 1, -1, -1):
		var card := give_hand(1, names[i])
		g.put_from_hand_on_top_of_library(card)
		out.push_front(card)
	return out


func _cast_selection_at(pid: int) -> void:
	var spell := give_hand(0, "Natural Selection")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(pid)]))
	resolve_stack()


func _top_names(pid: int, n: int) -> Array:
	var lib := g.players[pid].library
	var out: Array = []
	for i in n:
		out.append(lib[lib.size() - 1 - i].data.card_name)
	return out


func test_natural_selection_stacks_the_cards_in_the_order_named() -> void:
	var top := _stack_their_top(["Lightning Bolt", "Grizzly Bears", "Serra Angel"])
	var seat := _seat(0)
	seat.cards = [top[2].id, top[0].id, top[1].id]
	_cast_selection_at(1)
	assert_eq(_top_names(1, 3), ["Serra Angel", "Lightning Bolt", "Grizzly Bears"])
	assert_eq(seat.offered.size(), 3, "one pick per card, top first")
	assert_eq(seat.offered[0][0], "Select card order or DONE to shuffle.")
	assert_eq(seat.offered[0][1].size(), 3)
	assert_eq(seat.offered[2][1].size(), 1)
	assert_false(_log_has("shuffles their library"))


func test_natural_selection_may_have_that_player_shuffle() -> void:
	_stack_their_top(["Lightning Bolt", "Grizzly Bears", "Serra Angel"])
	var seat := _seat(0)
	seat.cards = [-1]            # DONE: shuffle instead
	var before: int = g.players[1].library.size()
	_cast_selection_at(1)
	assert_eq(g.players[1].library.size(), before, "nothing left the library")
	assert_true(_log_has("P1 shuffles their library"))
	assert_eq(seat.offered.size(), 1, "declining ends the ordering")


func test_natural_selection_hint_bricks_an_opponent_and_smooths_yourself() -> void:
	_stack_their_top(["Lightning Bolt", "Grizzly Bears", "Serra Angel"])
	_cast_selection_at(1)
	assert_eq(_top_names(1, 3), ["Serra Angel", "Grizzly Bears", "Lightning Bolt"],
		"priciest on top of THEIR library")
	# Your own: cheapest on top.
	for name in ["Serra Angel", "Grizzly Bears", "Lightning Bolt"]:
		g.put_from_hand_on_top_of_library(give_hand(0, name))
	var spell := give_hand(0, "Natural Selection")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(_top_names(0, 3), ["Lightning Bolt", "Grizzly Bears", "Serra Angel"])


func test_natural_selection_reorder_is_journaled() -> void:
	var top := _stack_their_top(["Lightning Bolt", "Grizzly Bears", "Serra Angel"])
	var before := _top_names(1, 3)
	var mark := g.make_mark()
	g.reorder_top_of_library(1, [top[2], top[0], top[1]])
	assert_eq(_top_names(1, 3), ["Serra Angel", "Lightning Bolt", "Grizzly Bears"])
	g.unmake_to(mark)
	g.end_search()
	assert_eq(_top_names(1, 3), before, "put back by the journal")


func test_reorder_top_of_library_refuses_cards_that_are_not_on_top() -> void:
	var top := _stack_their_top(["Lightning Bolt", "Grizzly Bears", "Serra Angel"])
	var deep: CardInstance = g.players[1].library[0]
	g.reorder_top_of_library(1, [deep, top[0]])
	assert_eq(_top_names(1, 3), ["Lightning Bolt", "Grizzly Bears", "Serra Angel"],
		"a card from the bottom is not one of the top two: nothing moves")


# ------------------------------------------------------------ Mana batteries --
#
# `@MANABATTERY` (Program/prompts.txt:566): "How many counters do you wish
# to spend for additional mana? \n(max: %d)" — the original's own count
# question, asked as the battery is tapped.

func _charged_battery(name: String, charges: int) -> CardInstance:
	var battery := put_battlefield(0, name)
	advance_to_step(Mtg.Step.MAIN1)
	for i in charges:
		g.untap_permanent(battery)
		add_mana(0, Mtg.ManaColor.C, 2)
		assert_ok(g.activate_ability(0, battery, 0, []))
		resolve_stack()
	g.untap_permanent(battery)
	g.players[0].mana_pool.clear()
	return battery


func test_mana_battery_spends_only_the_counters_its_controller_names() -> void:
	var battery := _charged_battery("Green Mana Battery", 3)
	var seat := _seat(0)
	seat.labels = ["1"]
	assert_ok(g.tap_for_mana(0, battery))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2,
		"one, plus one per counter removed")
	assert_eq(int(battery.counters.get("charge", 0)), 2, "the rest stay on")
	assert_eq(seat.asked.size(), 1)
	assert_eq(seat.asked[0][0],
		"How many counters do you wish to spend for additional mana? (max: 3)")
	assert_eq(seat.asked[0][1], ["0", "1", "2", "3"])
	assert_true(seat.asked[0][1].size() == 4)


func test_mana_battery_may_spend_none() -> void:
	var battery := _charged_battery("Red Mana Battery", 2)
	var seat := _seat(0)
	seat.labels = ["0"]
	assert_ok(g.tap_for_mana(0, battery))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_eq(int(battery.counters.get("charge", 0)), 2)


func test_mana_battery_hint_spends_them_all_and_asks_nothing_when_empty() -> void:
	var battery := _charged_battery("Blue Mana Battery", 2)
	var seat := _seat(0)
	assert_ok(g.tap_for_mana(0, battery))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 3)
	assert_eq(int(battery.counters.get("charge", 0)), 0)
	g.untap_permanent(battery)
	g.players[0].mana_pool.clear()
	assert_ok(g.tap_for_mana(0, battery))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	assert_eq(seat.asked.size(), 1, "no counters, no question")


func test_mana_battery_count_holds_a_human_seat_open() -> void:
	var battery := _charged_battery("White Mana Battery", 2)
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	assert_ok(g.tap_for_mana(0, battery))
	assert_not_null(g.awaiting_choice, "held open on the count")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_true(g.awaiting_choice.is_cost)
	assert_eq(g.awaiting_choice.source, "White Mana Battery")
	assert_false(battery.tapped, "nothing paid while the question is open")
	assert_eq(int(battery.counters.get("charge", 0)), 2)
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_true(battery.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 2)
	assert_eq(int(battery.counters.get("charge", 0)), 1)
	assert_eq(g.unanswered_choices.size(), 0, "the player answered it themselves")


func test_mana_battery_discharge_is_journaled() -> void:
	var battery := _charged_battery("Black Mana Battery", 2)
	var mark := g.make_mark()
	assert_ok(g.tap_for_mana(0, battery))
	assert_eq(int(battery.counters.get("charge", 0)), 0)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(int(battery.counters.get("charge", 0)), 2, "the counters come back")
	assert_false(battery.tapped)


# ---------------------------------------------------------------- Mana Flare --
#
# Duel.hlp, Mana Flare: "If the ability that was used produces mana of more
# than one type, you can choose which type of mana is produced by Mana
# Flare." No land in this pool makes two types on one tap; a synthetic one
# pins the choice.

func _two_type_land() -> CardData:
	return CardData.new("Confluence", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).and_also(Mtg.ManaColor.U))


func test_mana_flare_lets_the_tapper_pick_among_the_types_produced() -> void:
	put_battlefield(1, "Mana Flare")
	var land := put_synthetic(0, _two_type_land())
	var seat := _seat(0)
	seat.labels = ["Blue"]
	assert_ok(g.tap_for_mana(0, land))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2, "the bonus is the type they named")
	assert_eq(seat.asked.size(), 1)
	assert_eq(seat.asked[0][0], "Mana Flare: What kind of mana?")
	assert_eq(seat.asked[0][1], ["White", "Blue"])


func test_mana_flare_asks_nothing_of_a_land_that_made_one_type() -> void:
	put_battlefield(1, "Mana Flare")
	var forest := put_battlefield(0, "Forest")
	var seat := _seat(0)
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2)
	assert_eq(seat.asked.size(), 0, "one type produced: nothing to choose")


func test_mana_flare_asks_once_per_flare() -> void:
	put_battlefield(1, "Mana Flare")
	put_battlefield(0, "Mana Flare")
	var land := put_synthetic(0, _two_type_land())
	var seat := _seat(0)
	seat.labels = ["Blue", "White"]
	assert_ok(g.tap_for_mana(0, land))
	assert_eq(seat.asked.size(), 2, "a separate choice for each Mana Flare (Duel.hlp)")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 2)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2)


# --------------------------------------------- Magical Hack / Sleight of Mind --
#
# `@MAGICAL_HACK` (Program/prompts.txt:561): "Select target permanent." /
# "Hacking %s to %s." and `@SLEIGHT_OF_MIND` (prompts.txt:806): "Select
# target permanent." / "Sleighting %s to %s." — the pair of words is the
# caster's, one question each.

func test_magical_hack_rewrites_the_pair_of_types_the_caster_names() -> void:
	put_battlefield(0, "Island")           # the hint would pick island
	var walker := put_battlefield(1, "Bog Wraith")   # swampwalk
	var seat := _seat(0)
	seat.labels = ["swamp", "mountain"]
	var hack := give_hand(0, "Magical Hack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, hack, [TargetRef.card(walker)]))
	resolve_stack()
	assert_true(walker.cur_landwalk.has("mountain"), "mountainwalk, as named")
	assert_false(walker.cur_landwalk.has("swamp"))
	assert_false(walker.cur_landwalk.has("island"), "not the hint's island")
	assert_eq(seat.asked.size(), 2)
	assert_eq(seat.asked[0][1], ["swamp"], "only the words the text has")
	assert_eq(seat.asked[1][1], ["plains", "island", "mountain", "forest"],
		"every other basic type")
	assert_true(_log_has("Hacking swamp to mountain."))


func test_magical_hack_offers_every_type_a_dual_land_carries() -> void:
	var taiga := put_battlefield(1, "Taiga")   # mountain forest
	var seat := _seat(0)
	seat.labels = ["forest", "plains"]
	var hack := give_hand(0, "Magical Hack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, hack, [TargetRef.card(taiga)]))
	resolve_stack()
	assert_eq(seat.asked[0][1], ["mountain", "forest"])
	assert_true(taiga.has_subtype("plains"))
	assert_true(taiga.has_subtype("mountain"))
	assert_false(taiga.has_subtype("forest"))


func test_sleight_of_mind_rewrites_the_pair_of_colours_the_caster_names() -> void:
	var knight := put_battlefield(1, "Black Knight")   # protection from white
	var seat := _seat(0)
	seat.labels = ["White", "Green"]
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, sleight, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.cur_protection, Mtg.ManaColor.G, "protection from green, as named")
	assert_eq(seat.asked.size(), 2)
	assert_eq(seat.asked[0][1], ["White"], "only the colour words the text has")
	assert_eq(seat.asked[1][1], ["Blue", "Black", "Red", "Green"])
	assert_true(_log_has("Sleighting White to Green."))


func test_sleight_of_mind_hint_takes_protection_off_what_you_play() -> void:
	var knight := put_battlefield(1, "Black Knight")
	put_battlefield(0, "Savannah Lions")     # you play white; the hint moves it
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, sleight, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.cur_protection & Mtg.ManaColor.W, 0, "white gone")
	assert_ne(knight.cur_protection, 0, "and another colour in its place")


# --------------------------------------------------------- Worms of the Earth --
#
# No 1997 line exists for the Worms (a Dark card; Duel.hlp and the prompt
# tables cover the base set) — the labels are the oracle's own words.

const WORM_WAYS := ["Sacrifice two lands.", "Take 5 damage.", "Do nothing."]


func test_worms_of_the_earth_offer_the_escape_to_the_other_player_too() -> void:
	# The seat that is NOT the active player is asked as well — after the
	# active player (APNAP, CR 101.4) — and its two lands are its own pick.
	var a := put_battlefield(1, "Forest")
	var b := put_battlefield(1, "Forest")
	var c := put_battlefield(1, "Forest")
	var worms := put_battlefield(0, "Worms of the Earth")
	var theirs := _seat(1)
	var ours := _seat(0)
	theirs.labels = ["Do nothing."]      # their own upkeep: they wait
	advance_to_next_turn()               # turn 2, P1's
	assert_eq(worms.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.asked.size(), 1)
	assert_eq(ours.asked.size(), 1, "the Worms' controller is asked too")
	assert_eq(theirs.asked[0][1], WORM_WAYS)
	theirs.labels = ["Sacrifice two lands."]
	theirs.cards = [c.id, a.id]
	advance_to_next_turn()               # turn 3, OUR upkeep: they are still asked
	assert_eq(worms.zone, Mtg.Zone.GRAVEYARD, "broken on the controller's upkeep by the other player")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(c.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.BATTLEFIELD, "the land they kept")
	assert_eq(ours.asked.size(), 2)
	assert_eq(theirs.offered.size(), 2)
	assert_eq(theirs.offered[0][0], "Select land to sacrifice.")


func test_worms_of_the_earth_asks_the_active_player_first() -> void:
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	put_battlefield(0, "Worms of the Earth")
	var order: Array = []
	var s0 := _seat(0)
	var s1 := _seat(1)
	s0.labels = ["Do nothing."]
	s1.labels = ["Do nothing."]
	# Read the order off the choice log: the first OPTION filed at P1's
	# upkeep is P1's (active), the second P0's.
	advance_to_next_turn()
	for choice in g.choice_log:
		if choice.kind == PlayerChoice.Kind.OPTION and choice.source == "Worms of the Earth":
			order.append(choice.pid)
	assert_eq(order, [1, 0], "APNAP: the active player decides first")


func test_worms_of_the_earth_take_5_damage_when_the_lands_are_short() -> void:
	put_battlefield(1, "Forest")
	var worms := put_battlefield(0, "Worms of the Earth")
	var theirs := _seat(1)
	theirs.labels = ["Take 5 damage."]
	advance_to_next_turn()
	assert_eq(theirs.asked[0][1], ["Take 5 damage.", "Do nothing."],
		"one land: sacrificing two is not on the list")
	assert_eq(g.players[1].life, 15)
	assert_eq(worms.zone, Mtg.Zone.GRAVEYARD)


func test_worms_of_the_earth_controller_hint_does_nothing() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var worms := put_battlefield(0, "Worms of the Earth")
	var theirs := _seat(1)
	theirs.labels = ["Do nothing.", "Do nothing."]
	advance_to_next_turn()
	advance_to_next_turn()               # our own upkeep: the hint keeps them
	assert_eq(worms.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].battlefield.size(), 3, "our lands stay")
	assert_eq(g.players[0].life, 20)


func test_worms_of_the_earth_hint_for_the_other_player_breaks_them() -> void:
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var worms := put_battlefield(0, "Worms of the Earth")
	advance_to_next_turn()
	assert_eq(worms.zone, Mtg.Zone.GRAVEYARD, "two lands: the hint pays them")
	assert_eq(g.players[1].battlefield.size(), 0)


func test_worms_of_the_earth_hint_will_not_take_5_at_5_life() -> void:
	var worms := put_battlefield(0, "Worms of the Earth")
	g.players[1].life = 5
	advance_to_next_turn()
	assert_eq(worms.zone, Mtg.Zone.BATTLEFIELD, "the hint does not kill its own player")
	assert_eq(g.players[1].life, 5)


func test_worms_of_the_earth_one_escape_is_enough() -> void:
	# Both players act in the same upkeep: the Worms are destroyed once and
	# each payer pays — the printed "if a player does either".
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var worms := put_battlefield(0, "Worms of the Earth")
	var ours := _seat(0)
	ours.labels = ["Take 5 damage."]
	advance_to_next_turn()
	assert_eq(worms.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15)
	assert_eq(g.players[1].battlefield.size(), 0)


# --------------------------------------------------------------- Mana Vault --
#
# CR 504.1: the draw is the step's first turn-based action, and a "beginning
# of your draw step" trigger goes on the stack only when a player would
# next receive priority (CR 603.3) — AFTER that draw. The engine's order
# was the printed one all along.

func test_mana_vault_burn_goes_on_the_stack_after_the_turns_draw() -> void:
	var vault := put_battlefield(0, "Mana Vault")
	advance_to_step(Mtg.Step.MAIN1)       # past turn 1's own draw step
	g.tap_permanent(vault)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)      # our turn 3
	assert_eq(g.active_player, 0)
	resolve_stack()                       # the {4} offer, declined for want of mana
	var hand := g.players[0].hand.size()
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.players[0].hand.size(), hand + 1, "drawn first (CR 504.1)")
	assert_eq(g.stack.size(), 1, "then the burn is put on the stack (CR 603.3)")
	assert_eq(g.players[0].life, 20, "not yet dealt")
	resolve_stack()
	assert_eq(g.players[0].life, 19)


func test_mana_vault_empty_library_loss_comes_before_the_burn() -> void:
	# CR 704.5b is checked before anyone receives priority — before the
	# burn resolves. With one life and nothing to draw, the draw loses.
	var vault := put_battlefield(0, "Mana Vault")
	advance_to_step(Mtg.Step.MAIN1)
	g.tap_permanent(vault)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	g.players[0].library.clear()
	g.players[0].life = 1
	advance_to_step(Mtg.Step.DRAW)
	assert_true(g.game_over)
	assert_true(_log_has("empty library") or _log_has("draws from an empty"),
		"lost to the draw, not to the Vault")
