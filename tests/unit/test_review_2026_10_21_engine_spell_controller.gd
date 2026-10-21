extends GameTest
## Whole-project review of 2026-10-21, engine-2 — A SPELL IS CONTROLLED BY
## THE PLAYER WHO CAST IT (CR 110.2: "a spell's controller is, by default,
## the player who put it on the stack"), owner or not.
##
## What was wrong: MtgGame.cast_spell moved the card to the stack and
## recorded StackItem.controller, but left CardInstance.controller_id at the
## card's OWNER. Grinning Totem lets a player cast a card out of the
## opponent's library, and every reader of the card's controller saw the
## wrong seat: "target opponent" was judged from the owner's side (the
## stolen Mana Clash could be aimed at its own caster and not at the
## opponent), the fizzle check did the same on resolution, and
## source_controller() — what Reflect Damage and Eye for an Eye send the
## damage back to — named the owner, so a stolen Bolt reflected straight
## back at the player it was cast at. Now the card is the caster's while it
## is a spell (journaled), and goes home to its owner as it leaves the
## stack any way other than onto the battlefield.
## The owner's ruling on the review: "All!".


class Seat extends DecisionAgent:
	var picks: Array[String] = []
	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt)
	func choose_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String, optional := false, adverse := false, ordered := false) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt, optional, adverse, ordered)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	CardPacks.set_enabled("pack-8", false)


## P1's [param card_name], exiled and playable by P0 — the state Grinning
## Totem leaves behind (exile_library_card, then grant_exile_play).
func _stolen(card_name: String) -> CardInstance:
	var card := _make_instance(1, card_name)
	card.zone = Mtg.Zone.EXILE
	g.players[1].exile.append(card)
	g.grant_exile_play(card, 0)
	return card


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


# ------------------------------------------------------------ on the stack --

func test_a_stolen_spell_is_controlled_by_its_caster() -> void:
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.stack.back().controller, 0)
	assert_eq(bolt.controller_id, 0, "the spell is P0's")
	assert_eq(g.source_controller(bolt), 0, "and that is who 'its controller' names")
	assert_eq(bolt.owner_id, 1, "its owner does not change")


func test_a_stolen_target_opponent_spell_can_be_aimed_at_the_opponent() -> void:
	var clash := _stolen("Mana Clash")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, clash, [TargetRef.player(1)]))
	resolve_stack()
	assert_false(_log_has("Mana Clash fizzles"), "a legal 'target opponent' spell resolves")
	assert_eq(clash.zone, Mtg.Zone.GRAVEYARD)


func test_a_stolen_target_opponent_spell_cannot_aim_at_its_caster() -> void:
	var clash := _stolen("Mana Clash")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, clash, [TargetRef.player(0)]))
	assert_eq(clash.zone, Mtg.Zone.EXILE, "a refused cast leaves the card where it was")
	assert_eq(clash.controller_id, 1, "and leaves its controller alone")


func test_the_screens_and_the_ais_target_readers_ask_from_the_thiefs_seat() -> void:
	# What the duel screen, SGManalink and the AI aim with before a cast:
	# the prospective readers judge the stolen card from its would-be
	# caster's seat too, and give the card back untouched.
	var clash := _stolen("Mana Clash")
	var spec: TargetSpec = clash.data.spell_effects[0].target_spec
	assert_true(g.target_legal_at(spec, TargetRef.player(1), clash, 0), "P1 is P0's opponent")
	assert_false(g.target_legal_at(spec, TargetRef.player(0), clash, 0), "P0 is not its own")
	assert_ne(g.target_refusal_at(spec, TargetRef.player(0), clash, 0), "")
	var offered: Array[int] = []
	for ref in g.legal_targets_at(spec, clash, 0):
		offered.append(ref.player_id)
	assert_eq(offered, [1] as Array[int])
	assert_eq(clash.controller_id, 1, "the proposal is withdrawn")


func test_reflect_damage_sends_a_stolen_bolt_to_its_caster() -> void:
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	CardPacks.set_enabled("pack-8", true)
	var seat := Seat.new()
	seat.picks = ["Lightning Bolt"]
	g.set_agent(1, seat)
	var reflect := give_hand(1, "Reflect Damage")
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, reflect, []))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "Reflect Damage keeps the Bolt off P1")
	assert_eq(g.players[0].life, 17, "and deals it to the Bolt's controller, P0")


func test_eye_for_an_eye_answers_the_player_who_cast_the_stolen_bolt() -> void:
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var seat := Seat.new()
	seat.picks = ["Lightning Bolt"]
	g.set_agent(1, seat)
	var eye := give_hand(1, "Eye for an Eye")
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, eye, []))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the Bolt still hits P1")
	assert_eq(g.players[0].life, 17, "and the Eye hits the Bolt's controller, P0 — not P1 again")


# ---------------------------------------------------------- going home --

func test_a_resolved_stolen_spell_goes_home_to_its_owner() -> void:
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_true(g.players[1].graveyard.has(bolt), "its owner's graveyard")
	assert_eq(bolt.controller_id, 1, "off the stack a card is its owner's again")


func test_a_countered_stolen_spell_goes_home_to_its_owner() -> void:
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	g.counter_spell(bolt)
	assert_true(g.players[1].graveyard.has(bolt))
	assert_eq(bolt.controller_id, 1)


func test_a_fizzled_stolen_spell_goes_home_to_its_owner() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	g.destroy(bears)
	resolve_stack()
	assert_true(_log_has("Lightning Bolt fizzles"))
	assert_true(g.players[1].graveyard.has(bolt))
	assert_eq(bolt.controller_id, 1)


func test_a_stolen_permanent_spell_enters_under_its_caster() -> void:
	var bears := _stolen("Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bears, []))
	assert_eq(bears.controller_id, 0)
	resolve_stack()
	assert_true(g.players[0].battlefield.has(bears))
	assert_eq(bears.controller_id, 0, "a permanent spell stays its caster's (CR 110.2a)")


func test_the_journal_puts_the_owner_back_after_an_explored_cast() -> void:
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(bolt.controller_id, 0)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(bolt.controller_id, 1, "the explored cast is unmade, controller and all")
	var mark2 := g.make_mark()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.controller_id, 1)
	g.unmake_to(mark2)
	g.end_search()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(bolt.controller_id, 1, "and so is the trip home")


# -------------------------------------------------------- the real card --

func test_grinning_totem_steals_a_mana_clash_that_can_target_its_owner() -> void:
	CardPacks.set_enabled("pack-8", true)
	var totem := put_battlefield(0, "Grinning Totem")
	var clash := _make_instance(1, "Mana Clash")
	clash.zone = Mtg.Zone.LIBRARY
	g.players[1].library.append(clash)
	var seat := Seat.new()
	seat.picks = ["Mana Clash"]
	g.set_agent(0, seat)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, totem, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(clash.zone, Mtg.Zone.EXILE, "precondition: the Totem exiled it")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, clash, [TargetRef.player(0)]), "")
	assert_ok(g.cast_spell(0, clash, [TargetRef.player(1)]))
	resolve_stack()
	assert_false(_log_has("Mana Clash fizzles"))
	assert_true(g.players[1].graveyard.has(clash), "home to its owner's graveyard")
