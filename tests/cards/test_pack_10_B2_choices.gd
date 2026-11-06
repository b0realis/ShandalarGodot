extends GameTest
## Pack 10 (the Urza block), batch B2: the resolution choices of
## cards/sets/usg/_choices.gd (Catastrophe, Persecute, Victimize),
## cards/sets/ulg/_choices.gd (Parch) and cards/sets/ulg/_costs.gd
## (Pyromancy).
##
## Catastrophe's "lands or creatures" and Persecute's color are chosen as
## the spell resolves (CR 608.2d), held for a human seat; Persecute's
## hand is revealed to both seats. Victimize sacrifices on resolution and
## returns only the targets still in the graveyard. Parch is modal (CR
## 700.2). Pyromancy reads the mana value of the card its cost discarded
## at random.

const CLAIMED := ["Catastrophe", "Persecute", "Victimize", "Parch", "Pyromancy"]


class Recorder:
	var rows: Array = []
	func on_reveal(viewer: int, title: String, names: Array) -> void:
		rows.append({"viewer": viewer, "title": title, "names": names.duplicate()})


## Scripted answers: options by label, colors by mask, cards by name.
class Seat extends DecisionAgent:
	var labels: Array[String] = []
	var color := 0
	var picks: Array[String] = []
	var asked: Array[String] = []
	var offered: Array[String] = []
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		while not labels.is_empty():
			var at := options.find(labels.pop_front())
			if at >= 0: return at
		return hint
	func answer_color(_g: MtgGame, _pid: int, prompt: String, hint: int) -> int:
		asked.append(prompt)
		return color if color != 0 else hint
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates: offered.append(c.data.card_name)
		while not picks.is_empty():
			var want: String = picks.pop_front()
			for c in candidates:
				if c.data.card_name == want: return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pay(pid: int, card_name: String) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func _try(pid: int, card_name: String, targets: Array = [], mode := 0) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name)
	return g.cast_spell(pid, card, targets, 0, mode)

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

func _human(pid: int) -> void:
	g.set_agent(pid, HumanAgent.new())
	g.interactive_choices = true

func _release(pid: int) -> void:
	g.interactive_choices = false
	g.set_agent(pid, DecisionAgent.new())

func _pass_round() -> void:
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# -------------------------------------------------------------- Catastrophe --

func test_catastrophe_destroys_all_creatures_and_none_regenerates() -> void:
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	skeletons.regeneration_shields = 1
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	var seat := _seat(0)
	seat.labels = ["Destroy all creatures"]
	assert_ok(_try(0, "Catastrophe"))
	g.set_agent(1, DecisionAgent.new())
	resolve_stack()
	assert_eq(skeletons.zone, Mtg.Zone.GRAVEYARD, "creatures destroyed this way can't be regenerated")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)

func test_catastrophe_may_destroy_all_lands_instead() -> void:
	var forest := put_battlefield(1, "Forest")
	var mine := put_battlefield(0, "Plains")
	var giant := put_battlefield(1, "Hill Giant")
	var seat := _seat(0)
	seat.labels = ["Destroy all lands"]
	assert_ok(_try(0, "Catastrophe"))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_a_land_may_regenerate_from_catastrophe_unless_it_is_a_creature() -> void:
	var forest := put_battlefield(1, "Forest")
	forest.regeneration_shields = 1
	var factory := put_battlefield(1, "Mishra's Factory")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, factory, 0))
	resolve_stack()
	assert_true(factory.is_creature(), "an animated land")
	factory.regeneration_shields = 1
	var seat := _seat(0)
	seat.labels = ["Destroy all lands"]
	assert_ok(_try(0, "Catastrophe"))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "a land destroyed this way may regenerate")
	assert_true(forest.tapped)
	assert_eq(factory.zone, Mtg.Zone.GRAVEYARD, "a creature destroyed this way can't")

func test_catastrophe_hint_reads_the_board_trade() -> void:
	# Their army against our lone Bears: the creatures go.
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Craw Wurm")
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	assert_ok(_try(0, "Catastrophe"))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	# Our army and their lands: the lands go.
	before_each()
	var wurm := put_battlefield(0, "Craw Wurm")
	for n in 4: put_battlefield(1, "Forest")
	assert_ok(_try(0, "Catastrophe"))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.find_on_battlefield(1, "Forest"), null)

func test_a_human_chooses_lands_or_creatures_as_catastrophe_resolves() -> void:
	var forest := put_battlefield(1, "Forest")
	var giant := put_battlefield(1, "Hill Giant")
	_human(0)
	assert_ok(_try(0, "Catastrophe"))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked, "the choice is made on resolution, held for the human")
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.options, ["Destroy all lands", "Destroy all creatures"] as Array[String])
	assert_ok(g.answer_choice(0))
	_release(0)
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Persecute --

func test_persecute_reveals_the_hand_and_discards_every_card_of_the_chosen_color() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	var bolt := give_hand(1, "Lightning Bolt")
	var giant := give_hand(1, "Hill Giant")
	var growth := give_hand(1, "Giant Growth")
	var mountain := give_hand(1, "Mountain")
	var seat := _seat(0)
	seat.color = Mtg.ManaColor.R
	assert_ok(_try(0, "Persecute", [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(growth.zone, Mtg.Zone.HAND)
	assert_eq(mountain.zone, Mtg.Zone.HAND, "a land is colorless")
	assert_eq(rec.rows.size(), 1)
	if rec.rows.is_empty(): return
	assert_eq(int(rec.rows[0]["viewer"]), -1, "the hand is revealed to both seats")
	assert_eq((rec.rows[0]["names"] as Array).size(), 4)

func test_persecute_hint_names_the_color_the_target_shows_on_the_table() -> void:
	# Public facts only: their Mountains and their red creature say red;
	# what they hold does not move the answer (docs/fair-play.md).
	var kept: Array[String] = []
	for their in [["Giant Growth", "Llanowar Elves"], ["Lightning Bolt", "Giant Growth"]]:
		before_each()
		put_battlefield(1, "Mountain")
		put_battlefield(1, "Mountain")
		put_battlefield(1, "Hill Giant")
		for card_name in their: give_hand(1, card_name)
		assert_ok(_try(0, "Persecute", [TargetRef.player(1)]))
		resolve_stack()
		var left: Array[String] = []
		for c in g.players[1].hand: left.append(c.data.card_name)
		kept.append(", ".join(PackedStringArray(left)))
	assert_eq(kept, ["Giant Growth, Llanowar Elves", "Giant Growth"] as Array[String])

func test_a_human_chooses_persecutes_color_on_resolution() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var growth := give_hand(1, "Giant Growth")
	_human(0)
	assert_ok(_try(0, "Persecute", [TargetRef.player(1)]))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.COLOR)
	assert_eq(bolt.zone, Mtg.Zone.HAND, "nothing happens before the answer")
	assert_ok(g.answer_choice(Mtg.ManaColor.G))
	_release(0)
	resolve_stack()
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------------- Victimize --

func test_victimize_sacrifices_a_creature_and_returns_both_cards_tapped() -> void:
	var wurm := _grave(0, "Craw Wurm")
	var angel := _grave(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_try(0, "Victimize", [TargetRef.card(wurm), TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	for c in [wurm, angel]:
		assert_eq(c.zone, Mtg.Zone.BATTLEFIELD)
		assert_true(c.tapped, "%s returns tapped" % c.data.card_name)
		assert_eq(c.controller_id, 0)

func test_victimize_without_a_creature_to_sacrifice_returns_nothing() -> void:
	var wurm := _grave(0, "Craw Wurm")
	var angel := _grave(0, "Serra Angel")
	assert_ok(_try(0, "Victimize", [TargetRef.card(wurm), TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)

func test_victimize_needs_two_creature_cards_in_your_graveyard() -> void:
	var wurm := _grave(0, "Craw Wurm")
	var theirs := _grave(1, "Serra Angel")
	put_battlefield(0, "Grizzly Bears")
	assert_refused(_try(0, "Victimize", [TargetRef.card(wurm)]))
	assert_refused(_try(0, "Victimize", [TargetRef.card(wurm), TargetRef.card(theirs)]))

func test_victimize_returns_the_target_still_in_the_graveyard() -> void:
	var wurm := _grave(0, "Craw Wurm")
	var angel := _grave(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_try(0, "Victimize", [TargetRef.card(wurm), TargetRef.card(angel)]))
	g.exile_from_graveyard(angel)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(angel.zone, Mtg.Zone.EXILE)

func test_a_human_chooses_victimizes_sacrifice_on_resolution() -> void:
	var wurm := _grave(0, "Craw Wurm")
	var angel := _grave(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_human(0)
	assert_ok(_try(0, "Victimize", [TargetRef.card(wurm), TargetRef.card(angel)]))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.candidates.has(bear) and asked.candidates.has(giant))
	assert_ok(g.answer_choice(giant.id))
	_release(0)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------------- Parch --

func test_parch_deals_two_to_any_target() -> void:
	assert_ok(_try(0, "Parch", [TargetRef.player(1)], 0))
	resolve_stack()
	assert_eq(g.players[1].life, 18)

func test_parch_deals_four_to_a_blue_creature_only() -> void:
	var elemental := put_battlefield(1, "Air Elemental")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(_try(0, "Parch", [TargetRef.card(giant)], 1))
	assert_refused(_try(0, "Parch", [TargetRef.player(1)], 1))
	assert_ok(_try(0, "Parch", [TargetRef.card(elemental)], 1))
	resolve_stack()
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD)

func test_parch_is_an_instant() -> void:
	var data := CardRegistry.get_card("Parch")
	assert_true(data.is_type(Mtg.CardType.INSTANT))
	assert_eq(data.modes.size(), 2)


# ---------------------------------------------------------------- Pyromancy --

func _pyromancy() -> CardInstance:
	return put_battlefield(0, "Pyromancy")

func test_pyromancy_deals_the_discarded_cards_mana_value() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var pyro := _pyromancy()
		var dragon := give_hand(0, "Shivan Dragon")
		add_mana(0, Mtg.ManaColor.C, 3)
		assert_ok(g.activate_ability(0, pyro, 0, [TargetRef.player(1)]))
		assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "%s: discarded as the cost is paid" % preset)
		resolve_stack()
		assert_eq(g.players[1].life, 14, preset)

func test_pyromancy_counts_x_as_zero_and_needs_a_card_to_discard() -> void:
	var pyro := _pyromancy()
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, pyro, 0, [TargetRef.player(1)]))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3, "nothing paid")
	give_hand(0, "Fireball")
	assert_ok(g.activate_ability(0, pyro, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "Fireball's mana value is 1")

func test_pyromancy_damage_comes_from_the_enchantment_even_if_it_has_left() -> void:
	var pyro := _pyromancy()
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, pyro, 0, [TargetRef.card(bear)]))
	g.destroy(pyro)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
