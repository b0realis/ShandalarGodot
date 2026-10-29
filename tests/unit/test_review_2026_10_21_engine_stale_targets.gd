extends GameTest
## Whole-project review of 2026-10-21, engine-1 — A TARGET THAT LEFT AND
## CAME BACK IS A NEW OBJECT (CR 400.7), for spells and activated abilities
## too.
##
## What was wrong: a TargetRef names a card by instance id, and a card keeps
## its id when it leaves the battlefield and returns, so a spell or an
## activated ability whose target was bounced and recast (Aluren), or let
## out of a Tawnos's Coffin in response, found "its" target on the
## battlefield again and hit the NEW object: a Terror destroyed the recast
## Shrieking Drake, a Lightning Bolt killed the returned Grizzly Bears, a
## Holy Strength attached to them. Triggers already remembered which zone
## incarnation they aimed at (StackItem.trigger_target_incarnations) and so
## did Pack 9's delayed spells; ordinary casts and activations did not.
## They now record it as they go on the stack (StackItem.target_incarnations)
## and the fizzle checks compare it (MtgGame._target_still_chosen).
## The owner's ruling on the review: "All!".


class Seat extends DecisionAgent:
	var picks: Array[String] = []
	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt)
	func choose_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String, optional := false, adverse := false, ordered := false, copying := false) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt, optional, adverse, ordered, copying)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	for id in ["pack-8", "pack-9"]:
		CardPacks.set_enabled(id, false)


## Leave the battlefield and come straight back — what a Tawnos's Coffin
## untapped in response, or an Aluren recast, does.
func _blink(inst: CardInstance, pid: int) -> void:
	g.return_to_hand(inst)
	g.players[pid].hand.erase(inst)
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


# ----------------------------------------------------------------- spells --

func test_a_bolt_at_a_creature_that_blinked_fizzles() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var stamp := bears.layer_timestamp
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	_blink(bears, 1)
	assert_ne(bears.layer_timestamp, stamp, "precondition: a new object")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Bolt's target is gone: it fizzles")
	assert_eq(bears.damage, 0)
	assert_true(_log_has("Lightning Bolt fizzles"))
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_an_aura_at_a_creature_that_blinked_fizzles_to_the_graveyard() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bears)]))
	_blink(bears, 1)
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "Holy Strength never attaches to the new Bears")
	assert_true(bears.attachments.is_empty())


func test_a_graveyard_target_that_left_and_came_back_is_a_new_card() -> void:
	var bears := _make_instance(0, "Grizzly Bears")
	bears.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(bears)
	var raise := give_hand(0, "Raise Dead")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, raise, [TargetRef.card(bears)]))
	g.return_from_graveyard_to_hand(bears)
	g.discard_cards(0, [bears])
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "precondition: back in the graveyard")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "Raise Dead's card left the graveyard: it fizzles")


func test_a_target_that_only_changed_control_is_still_the_same_object() -> void:
	# A control change is not a zone change (CR 400.7 does not apply): the
	# guard must not turn it into a fizzle.
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	g.change_control(bears, 0)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the same Bears, now P0's, still dies")


func test_only_the_blinked_target_of_two_drops_out() -> void:
	# CR 608.2c: one illegal target out of two — the rest still happens.
	var fireball := give_hand(0, "Fireball")
	var bears := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, fireball,
		[TargetRef.card(bears, 2), TargetRef.card(elves, 2)], 4))
	_blink(elves, 1)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the Bears were still the Bears")
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, "the new Elves were never targeted")
	assert_eq(elves.damage, 0)


func test_a_redirected_spell_is_pinned_to_its_new_target() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	assert_true(g.retarget_spell(bolt, 0, TargetRef.card(elves)))
	_blink(elves, 1)
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, "the new target left and came back: fizzle")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "and the old one is no target at all")


func test_a_redirect_to_a_creature_that_stays_still_lands() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	_blink(bears, 1)   # the OLD target moves; the new one does not
	assert_true(g.retarget_spell(bolt, 0, TargetRef.card(elves)))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


func test_a_copy_that_keeps_the_original_targets_keeps_the_original_object() -> void:
	# CR 707.10: a copy copies the choices made for the original, so it is
	# aimed at the Bears that were targeted, not at the ones standing there
	# now.
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	_blink(bears, 1)
	var copy := g.copy_spell_on_stack(bolt, 0)
	assert_not_null(copy)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "neither the copy nor the Bolt hits the new Bears")
	assert_eq(bears.damage, 0)


# ------------------------------------------------------ activated abilities --

func test_a_ping_at_a_creature_that_blinked_is_countered() -> void:
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(elves)]))
	_blink(elves, 1)
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, "the ping's target is gone: countered on resolution")
	assert_true(_log_has("is countered (no legal targets)"))


func test_a_ping_still_lands_on_a_creature_that_stayed() -> void:
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------ the search journal --

func test_a_search_that_explores_a_blink_leaves_the_bolt_on_the_same_bears() -> void:
	# The incarnation is read off the journaled fields (zone, the
	# battlefield stamp), so a search that blinks the Bears and unmakes it
	# hands the real game back the very Bears the Bolt was aimed at.
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	var mark := g.make_mark()
	_blink(bears, 1)
	g.unmake_to(mark)
	g.end_search()
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the blink was never real: the Bolt kills them")


# ------------------------------------------------------- the real-card line --

func test_aluren_recast_in_response_dodges_terror() -> void:
	# The finding's own line, real cards only: P1 Unsummons its Shrieking
	# Drake in answer to a Terror and recasts it free through Aluren's row.
	for id in ["pack-8", "pack-9"]:
		CardPacks.set_enabled(id, true)
	var seat := Seat.new()
	# The Drake's "return a creature you control" takes the Bears as it is
	# set up, and the Elves when it is recast.
	seat.picks = ["Grizzly Bears", "Llanowar Elves"]
	g.set_agent(1, seat)
	put_battlefield(1, "Aluren")
	put_battlefield(1, "Grizzly Bears")
	var drake := put_battlefield(1, "Shrieking Drake")
	put_battlefield(1, "Llanowar Elves")
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "precondition: the set-up trigger took the Bears")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(drake)]))
	var unsummon := give_hand(1, "Unsummon")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, unsummon, [TargetRef.card(drake)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))   # Unsummon resolves
	assert_eq(drake.zone, Mtg.Zone.HAND)
	var rows := g.payment_rows(1, drake)
	var alt := -1
	for i in rows.size():
		if int(rows[i].get("granted_by", -1)) >= 0:
			alt = i
	assert_gt(alt, -1, "precondition: Aluren offers its row")
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, drake, [], 0, alt))
	var guard := 0
	while g.stack.size() > 1 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "the recast Drake is a new object: Terror fizzles")
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)
	assert_true(_log_has("Terror fizzles"))
