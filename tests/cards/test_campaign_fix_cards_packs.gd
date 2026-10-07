extends GameTest
## Whole-game campaign 2026-10 (fix-cards): card fixes in packs 2-9.
##   w3-7  Imposing Visage (Ice Age) and Goblin War Drums (Fallen Empires)
##         GRANT menace — layer 6 (CR 613.1f), so a newer Humility takes it
##         away and an older one does not (CR 613.7).
##   w2-6  Deep Spawn: the keep-it hint never decks its controller, and a
##         Spawn that has left is not asked about.
##   w2-7  Icy Prison: the "any player pays {3}" hint is per seat — never
##         the owner of the card it holds.
##   w2-9  Demonic Consultation: the default name is the best NONLAND card
##         with a copy unaccounted for.
##   w2-10 Lim-Dûl's Vault: each look is shown to the caster and followed
##         by a yes/no "pay 1 life and look again", hinted from its five.
##   w3-6  Phyrexian Dreadnought: a TOKEN copy (Echo Chamber's one-turn
##         body) is worth creatures only when it swings for lethal now.
##   w1-1  (wave 2, with fix-mana) Overgrowth describes its {G}{G} bonus on
##         the enchanted land, so ManaPlanner plans with it.

const PACKS := ["pack-2", "pack-3", "pack-5", "pack-8", "pack-9"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


## Records yes/no and option asks; answers the hint.
class Spy extends DecisionAgent:
	var yes_no: Array = []      # [prompt, hint]
	var options: Array = []     # [prompt, labels, hint]
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		yes_no.append([prompt, hint])
		return hint
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			labels: Array[String], hint: int) -> int:
		options.append([prompt, labels.duplicate(), hint])
		return hint


func _spy(pid: int) -> Spy:
	var spy := Spy.new()
	g.set_agent(pid, spy)
	return spy


func _asked(spy: Spy, contains: String) -> Array:
	return spy.yes_no.filter(func(row: Array) -> bool: return String(row[0]).contains(contains))


# ------------------------------------------- menace grants under Humility --

func test_imposing_visage_menace_is_lost_to_a_newer_humility() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var visage := _make_instance(0, "Imposing Visage")
	g._put_on_battlefield(visage, 0, bear)
	g.recalculate()
	assert_eq(bear.cur_min_blockers, 2, "Imposing Visage gives menace")
	put_battlefield(1, "Humility")
	g.recalculate()
	assert_eq(bear.cur_min_blockers, 1, "a newer Humility removes it")


func test_imposing_visage_newer_than_humility_keeps_its_menace() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Humility")
	var bear := put_battlefield(0, "Grizzly Bears")
	var visage := _make_instance(0, "Imposing Visage")
	g._put_on_battlefield(visage, 0, bear)
	g.recalculate()
	assert_eq(bear.cur_power, 1, "precondition: Humility applies")
	assert_eq(bear.cur_min_blockers, 2, "the newer grant applies after Humility")


func test_goblin_war_drums_menace_is_lost_to_a_newer_humility() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Goblin War Drums")
	g.recalculate()
	assert_eq(bear.cur_min_blockers, 2, "Goblin War Drums gives menace")
	put_battlefield(1, "Humility")
	g.recalculate()
	assert_eq(bear.cur_min_blockers, 1, "a newer Humility removes it")


func test_goblin_war_drums_newer_than_humility_keeps_its_menace() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Humility")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Goblin War Drums")
	g.recalculate()
	assert_eq(bear.cur_min_blockers, 2)


# ------------------------------------------------------------- Deep Spawn --

func _spawn_upkeep_with_library(cards: int) -> Array:
	var spy := _spy(0)
	var spawn := put_battlefield(0, "Deep Spawn")
	advance_to_next_turn()          # P1's turn
	while g.players[0].library.size() > cards: g.players[0].library.pop_back()
	var guard := 0
	while not g.game_over and guard < 200 and not (g.active_player == 0
			and g.current_step() == Mtg.Step.UPKEEP and not g.stack.is_empty()):
		_advance_once()
		guard += 1
	resolve_stack()
	return [spy, spawn]


func test_deep_spawn_hint_never_mills_the_last_cards_needed_to_draw() -> void:
	var run := _spawn_upkeep_with_library(3)
	var spy: Spy = run[0]
	var asks := _asked(spy, "Deep Spawn")
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_false(bool(asks[0][1]), "three cards: milling two decks it next turn")
	assert_eq((run[1] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "sacrificed instead")
	assert_eq(g.players[0].library.size(), 3)


func test_deep_spawn_hint_mills_while_two_draws_are_left() -> void:
	var run := _spawn_upkeep_with_library(4)
	var asks := _asked(run[0], "Deep Spawn")
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_true(bool(asks[0][1]))
	assert_eq((run[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].library.size(), 2)


func test_a_deep_spawn_that_has_left_is_not_asked_about() -> void:
	var spy := _spy(0)
	var spawn := put_battlefield(0, "Deep Spawn")
	advance_to_next_turn()
	var guard := 0
	while not g.game_over and guard < 200 and not (g.active_player == 0
			and g.current_step() == Mtg.Step.UPKEEP and not g.stack.is_empty()):
		_advance_once()
		guard += 1
	var before := g.players[0].library.size()
	g.return_to_hand(spawn)   # setup: bounced in response
	resolve_stack()
	assert_eq(_asked(spy, "Deep Spawn").size(), 0, "nothing left to keep")
	assert_eq(g.players[0].library.size(), before, "nothing milled")


# ------------------------------------------------------------- Icy Prison --

func test_icy_prison_hint_is_no_for_the_owner_of_the_card_it_holds() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spies := [_spy(0), _spy(1)]
	var wurm := put_battlefield(1, "Craw Wurm")
	var prison := put_battlefield(0, "Icy Prison")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.EXILE, "precondition: the Prison took the Wurm")
	for pid in 2:
		for n in 3: put_battlefield(pid, "Forest")
	advance_to_next_turn()      # P1's turn
	advance_to_next_turn()      # P0's upkeep has gone by
	var mine := _asked(spies[0], "Icy Prison")
	var theirs := _asked(spies[1], "Icy Prison")
	assert_eq(mine.size(), 1)
	assert_eq(theirs.size(), 0, "the controller paid: nobody else is asked")
	if mine.size() == 1:
		assert_true(bool(mine[0][1]), "the Prison's controller does not own the Wurm")
	assert_eq(prison.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.EXILE)


func test_icy_prison_owner_of_the_prisoner_is_hinted_not_to_pay() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spies := [_spy(0), _spy(1)]
	var wurm := put_battlefield(1, "Craw Wurm")
	var prison := put_battlefield(0, "Icy Prison")
	resolve_stack()
	for n in 3: put_battlefield(1, "Forest")   # only the prisoner's owner can pay
	advance_to_next_turn()
	advance_to_next_turn()
	var theirs := _asked(spies[1], "Icy Prison")
	assert_eq(theirs.size(), 1)
	if theirs.size() == 1:
		assert_false(bool(theirs[0][1]), "keeping its own Wurm exiled is never the hint")
	assert_eq(prison.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "the Wurm came home")


# --------------------------------------------------- Demonic Consultation --

func test_demonic_consultation_hint_names_the_best_nonland_with_a_copy_left() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	var names: Array[String] = []
	for n in 18: names.append("Swamp")
	for n in 4: names.append("Necropotence")
	for n in 4: names.append("Hypnotic Specter")
	for n in 4: names.append("Demonic Consultation")
	g.players[0].deck_names = names
	for n in 5: put_battlefield(0, "Swamp")
	g.players[0].library.clear()
	var lib := ["Hypnotic Specter"]   # the bottom
	for n in 12: lib.append("Swamp")
	for card_name in lib:
		var inst := _make_instance(0, card_name)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(inst)
	var dc := give_hand(0, "Demonic Consultation")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, dc, []))
	resolve_stack()
	assert_eq(spy.options.size(), 1)
	if spy.options.size() == 1:
		var labels: Array = spy.options[0][1]
		assert_eq(labels[0], "Swamp", "the list keeps its copies-left order")
		assert_eq(labels[int(spy.options[0][2])], "Hypnotic Specter", "the hint: the best nonland")
	var got: Array = []
	for i in g.players[0].hand: got.append(i.data.card_name)
	assert_eq(got, ["Hypnotic Specter"])


func test_demonic_consultation_hint_never_names_a_card_with_no_copy_left() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	g.players[0].deck_names = ["Swamp", "Swamp", "Hypnotic Specter", "Demonic Consultation"]
	put_battlefield(0, "Hypnotic Specter")   # the only Specter is accounted for
	var dc := give_hand(0, "Demonic Consultation")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, dc, []))
	resolve_stack()
	assert_eq(spy.options.size(), 1)
	if spy.options.size() == 1:
		var labels: Array = spy.options[0][1]
		assert_eq(labels[int(spy.options[0][2])], "Swamp", "a land beats a name with no copy left")


# -------------------------------------------------------- Lim-Dûl's Vault --

func _vault_library(top_five: String) -> void:
	g.players[0].library.clear()
	var lib: Array = []
	for n in 6: lib.append("Serra Angel")
	for n in 5: lib.append(top_five)      # the back of the array is the top
	for card_name in lib:
		var inst := _make_instance(0, card_name)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(inst)


func test_lim_duls_vault_digs_past_five_lands_when_flooded() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	for n in 8: put_battlefield(0, "Island")
	_vault_library("Island")
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, title: String, cards: Array) -> void:
		seen.append([viewer, title, cards.duplicate()]))
	var vault := give_hand(0, "Lim-Dûl's Vault")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, vault, []))
	resolve_stack()
	var asks := _asked(spy, "Lim-Dûl's Vault")
	assert_eq(asks.size(), 2, "dig past the Islands, keep the Angels")
	if asks.size() == 2:
		assert_true(bool(asks[0][1]))
		assert_false(bool(asks[1][1]))
	assert_eq(g.players[0].life, 19, "one life paid")
	assert_eq((g.players[0].library.back() as CardInstance).data.card_name, "Serra Angel")
	assert_eq(seen.size(), 2, "each look is shown")
	if seen.size() == 2:
		assert_eq(int(seen[0][0]), 0, "to the caster alone")
		assert_eq(seen[0][2], ["Island", "Island", "Island", "Island", "Island"])


func test_lim_duls_vault_keeps_lands_it_still_needs() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	for n in 2: put_battlefield(0, "Island")
	_vault_library("Island")
	var vault := give_hand(0, "Lim-Dûl's Vault")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, vault, []))
	resolve_stack()
	var asks := _asked(spy, "Lim-Dûl's Vault")
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_false(bool(asks[0][1]), "two lands in play: the Islands are wanted")
	assert_eq(g.players[0].life, 20)


# --------------------------------------------- Phyrexian Dreadnought token --

func _token_dreadnought(pid: int) -> CardInstance:
	var model := _make_instance(1 - pid, "Phyrexian Dreadnought")
	var made := g.create_token(pid, g.copiable_data(model))
	var token: CardInstance = made[0]
	g.continuous.add_until_eot_keywords(token.id, [Mtg.Keyword.HASTE])
	g.recalculate()
	return token


func test_a_token_dreadnought_is_not_kept_with_creatures_short_of_lethal() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	var w1 := put_battlefield(0, "Craw Wurm")
	var w2 := put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")      # a chump: no lethal through it
	var token := _token_dreadnought(0)
	resolve_stack()
	var asks := _asked(spy, "Phyrexian Dreadnought")
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_false(bool(asks[0][1]), "two Wurms for a one-turn body")
	assert_eq(w1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(w2.zone, Mtg.Zone.BATTLEFIELD)
	assert_ne(token.zone, Mtg.Zone.BATTLEFIELD)


func test_a_token_dreadnought_that_swings_for_lethal_is_kept() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears").tapped = true
	g.players[1].life = 12
	_token_dreadnought(0)
	resolve_stack()
	var asks := _asked(spy, "Phyrexian Dreadnought")
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_true(bool(asks[0][1]), "12 trample with haste into 12 life and no untapped blocker")


func test_a_card_dreadnought_keeps_its_old_hint() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spy := _spy(0)
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")
	var dread := give_hand(0, "Phyrexian Dreadnought")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, dread, []))
	resolve_stack()
	var asks := _asked(spy, "Phyrexian Dreadnought")
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_true(bool(asks[0][1]), "a permanent 12/12 for two bodies")


# ------------------------------------------- Overgrowth's bonus descriptor --

func test_overgrowth_describes_two_more_green_on_its_enchanted_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var host := put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var aura := _make_instance(0, "Overgrowth")
	g.attach_aura_from_anywhere(aura, host, 0)
	var amount := -1
	for s in ManaPlanner.sources(g, 0):
		if s[0] == host: amount = int(s[3])
	assert_eq(amount, 3, "the Forest's {G} and the Aura's {G}{G}")
	assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{2}{G}"), 0), [[host, 0]],
		"one tap of the enchanted Forest pays {2}{G}")
	assert_ok(g.tap_for_mana(0, host))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 3, "and the run makes what the plan read")
