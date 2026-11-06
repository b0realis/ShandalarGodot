extends GameTest
## Pack 10 (the Urza block), batch B2: the instants and sorceries of
## cards/sets/uds/_spells.gd other than the same-name exile family
## (tests/cards/test_pack_10_B2_same_name.gd) — Flicker, Solidarity,
## Donate, Fatigue, Rescue, Bubbling Muck, Encroach, Soul Feast, Landslide,
## Reckless Abandon, Trumpet Blast, Wake of Destruction, Magnify, Multani's
## Decree and Plow Under.
##
## Each card's main effect, its refused targets, and the choices it asks on
## resolution (Flicker's Aura host, Encroach's pick from the revealed hand,
## Landslide's "any number of Mountains", Plow Under's order) — the human
## seat's held path among them.

const CLAIMED := ["Flicker", "Solidarity", "Donate", "Fatigue", "Rescue", "Bubbling Muck",
	"Encroach", "Soul Feast", "Landslide", "Reckless Abandon", "Trumpet Blast",
	"Wake of Destruction", "Magnify", "Multani's Decree", "Plow Under"]


class Recorder:
	var rows: Array = []
	func on_reveal(viewer: int, title: String, names: Array) -> void:
		rows.append({"viewer": viewer, "title": title, "names": names.duplicate()})


## Scripted answers: numbers by queue, cards by name; remembers offers.
class Seat extends DecisionAgent:
	var numbers: Array[int] = []
	var picks: Array[String] = []
	var asked: Array[String] = []
	var offered: Array[String] = []
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		if not numbers.is_empty():
			var at := options.find(str(numbers.pop_front()))
			if at >= 0: return at
		return hint
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

func _try(pid: int, card_name: String, targets: Array = []) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name)
	return g.cast_spell(pid, card, targets)

func _cast_resolve(pid: int, card_name: String, targets: Array = []) -> void:
	assert_ok(_try(pid, card_name, targets))
	resolve_stack()

func _human(pid: int) -> void:
	g.set_agent(pid, HumanAgent.new())
	g.interactive_choices = true

func _release(pid: int) -> void:
	g.interactive_choices = false
	g.set_agent(pid, DecisionAgent.new())

func _pass_round() -> void:
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))

func _enchant(pid: int, aura: String, host: CardInstance) -> CardInstance:
	var card := give_hand(pid, aura)
	_pay(pid, aura)
	assert_ok(g.cast_spell(pid, card, [TargetRef.card(host)]))
	resolve_stack()
	return card


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------------ Flicker --

func test_flicker_returns_a_new_object_under_its_owners_control() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.change_control(bear, 0)
	g.add_counters(bear, "+1/+1")
	g.tap_permanent(bear)
	assert_eq(bear.controller_id, 0)
	var stamp := bear.layer_timestamp
	_cast_resolve(0, "Flicker", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 1, "its owner's control")
	assert_false(bear.tapped)
	assert_eq(bear.cur_power, 2, "counters gone")
	assert_ne(bear.layer_timestamp, stamp, "a new object (CR 400.7)")

func test_flicker_refuses_a_token() -> void:
	var token: CardInstance = g.create_token(0,
		CreateTokenEffect.new("Goblin", 1, 1, Mtg.ManaColor.R, "goblin").token)[0]
	assert_refused(_try(0, "Flicker", [TargetRef.card(token)]))
	assert_eq(token.zone, Mtg.Zone.BATTLEFIELD)

func test_a_flickered_aura_returns_on_a_host_its_owner_chooses() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var strength := _enchant(0, "Holy Strength", bear)
	assert_eq(strength.attached_to, bear.id)
	var seat := _seat(0)
	seat.picks = ["Hill Giant"]
	_cast_resolve(0, "Flicker", [TargetRef.card(strength)])
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, theirs.id)
	assert_eq(strength.controller_id, 0)
	assert_eq(theirs.cur_power, 4)

func test_a_human_owner_is_held_on_the_auras_host() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var strength := _enchant(0, "Holy Strength", bear)
	_human(0)
	assert_ok(_try(0, "Flicker", [TargetRef.card(strength)]))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.candidates.has(bear) and asked.candidates.has(theirs))
	assert_ok(g.answer_choice(bear.id))
	_release(0)
	resolve_stack()
	assert_eq(strength.attached_to, bear.id)
	assert_eq(bear.cur_power, 3)


# --------------------------------------------------------------- Solidarity --

func test_solidarity_gives_your_creatures_plus_zero_plus_five() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Solidarity")
	assert_eq(bear.cur_toughness, 7)
	assert_eq(bear.cur_power, 2)
	assert_eq(theirs.cur_toughness, 3)


# ------------------------------------------------------------------- Donate --

func test_donate_gives_your_permanent_to_the_target_player() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	_cast_resolve(0, "Donate", [TargetRef.player(1), TargetRef.card(ring)])
	assert_eq(ring.controller_id, 1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(ring.controller_id, 1, "for good")

func test_donate_targets_only_a_permanent_you_control() -> void:
	var theirs := put_battlefield(1, "Hill Giant")
	assert_refused(_try(0, "Donate", [TargetRef.player(0), TargetRef.card(theirs)]))
	assert_eq(theirs.controller_id, 1)


# ------------------------------------------------------------------ Fatigue --

func test_fatigue_skips_the_target_players_next_draw_step_only() -> void:
	_cast_resolve(0, "Fatigue", [TargetRef.player(1)])
	assert_eq(g.players[1].skip_draw_steps, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_eq(g.players[1].hand.size(), 0, "no draw this turn")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_eq(g.players[1].hand.size(), 1, "the next one draws again")


# ------------------------------------------------------------------- Rescue --

func test_rescue_returns_a_permanent_you_control_to_its_owners_hand() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_refused(_try(0, "Rescue", [TargetRef.card(theirs)]))
	_cast_resolve(0, "Rescue", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------ Bubbling Muck --

func test_bubbling_muck_adds_black_for_every_swamp_tapped_this_turn() -> void:
	var mine := put_battlefield(0, "Swamp")
	var theirs := put_battlefield(1, "Swamp")
	var island := put_battlefield(0, "Island")
	_cast_resolve(0, "Bubbling Muck")
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 2)
	assert_ok(g.tap_for_mana(0, island))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "Swamps only")
	assert_ok(g.tap_for_mana(1, theirs))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 2, "every player's Swamps")
	advance_to_next_turn()
	assert_true(g.delayed_triggers.is_empty(), "until end of turn")


# ----------------------------------------------------------------- Encroach --

func test_encroach_discards_the_chosen_nonbasic_land_card() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	var city := give_hand(1, "City of Brass")
	var forest := give_hand(1, "Forest")
	var bear := give_hand(1, "Grizzly Bears")
	var seat := _seat(0)
	_cast_resolve(0, "Encroach", [TargetRef.player(1)])
	assert_eq(city.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(seat.offered, ["City of Brass"] as Array[String], "only nonbasic land cards")
	assert_eq(rec.rows.size(), 1)
	if rec.rows.is_empty(): return
	assert_eq(int(rec.rows[0]["viewer"]), -1)
	assert_eq((rec.rows[0]["names"] as Array).size(), 3)

func test_encroach_on_a_hand_without_nonbasic_lands_still_reveals_it() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	var forest := give_hand(1, "Forest")
	var seat := _seat(0)
	_cast_resolve(0, "Encroach", [TargetRef.player(1)])
	assert_eq(forest.zone, Mtg.Zone.HAND)
	assert_true(seat.asked.is_empty())
	assert_eq(rec.rows.size(), 1)

func test_encroach_may_target_its_caster() -> void:
	var library := give_hand(0, "Library of Alexandria")
	_cast_resolve(0, "Encroach", [TargetRef.player(0)])
	assert_eq(library.zone, Mtg.Zone.GRAVEYARD)

func test_a_human_sees_the_revealed_hand_before_choosing() -> void:
	var city := give_hand(1, "City of Brass")
	var factory := give_hand(1, "Mishra's Factory")
	give_hand(1, "Grizzly Bears")
	_human(0)
	assert_ok(_try(0, "Encroach", [TargetRef.player(1)]))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	var shown := false
	for row in asked.information:
		if int(row.get("viewer", -2)) == -1 and (row.get("cards", []) as Array).has("Grizzly Bears"):
			shown = true
	assert_true(shown, "the whole hand, revealed to both seats, comes with the question")
	assert_ok(g.answer_choice(factory.id))
	_release(0)
	resolve_stack()
	assert_eq(factory.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(city.zone, Mtg.Zone.HAND)


# --------------------------------------------------------------- Soul Feast --

func test_soul_feast_drains_four() -> void:
	_cast_resolve(0, "Soul Feast", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 16)
	assert_eq(g.players[0].life, 24)


# ---------------------------------------------------------------- Landslide --

func test_landslide_sacrifices_the_chosen_mountains_for_that_much_damage() -> void:
	var a := put_battlefield(0, "Mountain")
	var b := put_battlefield(0, "Mountain")
	var c := put_battlefield(0, "Mountain")
	var forest := put_battlefield(0, "Forest")
	var seat := _seat(0)
	seat.numbers = [2]
	seat.picks = []
	_cast_resolve(0, "Landslide", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 18)
	var left := 0
	for m in [a, b, c]:
		if m.zone == Mtg.Zone.BATTLEFIELD: left += 1
	assert_eq(left, 1)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(seat.offered.has("Forest"), "Mountains only")

func test_landslide_targets_a_player() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Mountain")
	assert_refused(_try(0, "Landslide", [TargetRef.card(bear)]))

func test_landslide_hint_sacrifices_just_enough_for_lethal() -> void:
	for n in 4: put_battlefield(0, "Mountain")
	g.players[1].life = 3
	_cast_resolve(0, "Landslide", [TargetRef.player(1)])
	assert_true(g.players[1].life <= 0)
	var left := 0
	for i in g.players[0].battlefield:
		if i.data.card_name == "Mountain": left += 1
	assert_eq(left, 1)

func test_a_human_chooses_how_many_mountains_and_which() -> void:
	var tapped := put_battlefield(0, "Mountain")
	var untapped := put_battlefield(0, "Mountain")
	g.tap_permanent(tapped)
	_human(0)
	assert_ok(_try(0, "Landslide", [TargetRef.player(1)]))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.options, ["0", "1", "2"] as Array[String])
	assert_ok(g.answer_choice(1))
	asked = g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_ok(g.answer_choice(untapped.id))
	_release(0)
	resolve_stack()
	assert_eq(untapped.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(tapped.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 19)


# --------------------------------------------------------- Reckless Abandon --

func test_reckless_abandon_sacrifices_a_creature_as_it_is_cast() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_try(0, "Reckless Abandon", [TargetRef.player(1)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is a cost")
	resolve_stack()
	assert_eq(g.players[1].life, 16)

func test_reckless_abandon_needs_a_creature_to_sacrifice() -> void:
	assert_refused(_try(0, "Reckless Abandon", [TargetRef.player(1)]))
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------ Trumpet Blast --

func test_trumpet_blast_pumps_attacking_creatures_only() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_ok(_try(0, "Trumpet Blast"))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 2)
	assert_eq(home.cur_power, 3)
	assert_eq(theirs.cur_power, 6)


# ------------------------------------------------------ Wake of Destruction --

func test_wake_of_destruction_destroys_every_land_with_the_targets_name() -> void:
	var f1 := put_battlefield(1, "Forest")
	var f2 := put_battlefield(1, "Forest")
	var mine := put_battlefield(0, "Forest")
	var swamp := put_battlefield(1, "Swamp")
	_cast_resolve(0, "Wake of Destruction", [TargetRef.card(f1)])
	for f in [f1, f2, mine]:
		assert_eq(f.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD)

func test_wake_of_destruction_targets_a_land() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Wake of Destruction", [TargetRef.card(bear)]))


# ------------------------------------------------------------------ Magnify --

func test_magnify_gives_every_creature_plus_one() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Magnify")
	assert_eq(bear.cur_power, 3)
	assert_eq(theirs.cur_toughness, 4)


# --------------------------------------------------------- Multani's Decree --

func test_multanis_decree_gains_two_per_enchantment_destroyed() -> void:
	var crusade := put_battlefield(0, "Crusade")
	var moon := put_battlefield(1, "Bad Moon")
	var forest := put_battlefield(1, "Forest")
	var growth := _enchant(0, "Wild Growth", forest)
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Multani's Decree")
	for e in [crusade, moon, growth]:
		assert_eq(e.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 26)

func test_multanis_decree_with_no_enchantment_gains_nothing() -> void:
	_cast_resolve(0, "Multani's Decree")
	assert_eq(g.players[0].life, 20)


# --------------------------------------------------------------- Plow Under --

func test_plow_under_puts_two_lands_on_top_of_their_owners_libraries() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var mine := put_battlefield(0, "Plains")
	_cast_resolve(0, "Plow Under", [TargetRef.card(swamp), TargetRef.card(mine)])
	assert_eq(g.players[1].library.back(), swamp)
	assert_eq(g.players[0].library.back(), mine)

func test_plow_under_needs_two_different_lands() -> void:
	var swamp := put_battlefield(1, "Swamp")
	assert_refused(_try(0, "Plow Under", [TargetRef.card(swamp)]))
	assert_refused(_try(0, "Plow Under", [TargetRef.card(swamp), TargetRef.card(swamp)]))

func test_the_owner_orders_two_of_their_own_lands() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var island := put_battlefield(1, "Island")
	var them := _seat(1)
	them.picks = ["Island"]
	_cast_resolve(0, "Plow Under", [TargetRef.card(swamp), TargetRef.card(island)])
	var library := g.players[1].library
	assert_eq(library.back(), island, "the chosen land on top")
	assert_eq(library[library.size() - 2], swamp)
	assert_eq(them.asked.size(), 1, "the OWNER chooses (CR 401.4)")

func test_a_human_owner_is_held_on_the_order() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var island := put_battlefield(1, "Island")
	_human(1)
	assert_ok(_try(0, "Plow Under", [TargetRef.card(swamp), TargetRef.card(island)]))
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked, "the opponent's question is held while the caster's spell resolves")
	if asked == null: return
	assert_eq(asked.pid, 1)
	assert_ok(g.answer_choice(swamp.id))
	_release(1)
	resolve_stack()
	assert_eq(g.players[1].library.back(), swamp)
