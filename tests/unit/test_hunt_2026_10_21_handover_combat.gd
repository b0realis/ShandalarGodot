extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: three combat and dying
## readings in the engine.
##
## 1. "Creatures it was blocking that had become blocked by ONLY that
##    creature this combat become unblocked" (False Orders, Ydwen Efreet,
##    Imprison). WAS: `MtgGame.remove_from_combat` unblocked an attacker
##    whenever no blocker was LEFT on it, so an attacker blocked by two
##    whose first blocker had died walked through when False Orders took
##    the second. NOW it asks who blocked it this combat
##    (`MtgGame.combat_pair_history`): blocked by two, it stays blocked
##    (CR 509.1h, 506.4).
## 2. Disintegrate's "if it would die this turn, exile it instead" on a
##    TOKEN. WAS: a token was let die — its dies-triggers fired and it was
##    counted as a creature put into a graveyard. NOW a token is exiled
##    like any other creature (it then ceases to exist, CR 111.7) and never
##    dies.
## 3. "Must block X if able" against a BAND. WAS:
##    `CombatDeclaration.requirements_obeyed` counted a requirement only
##    for the attacker a creature was declared against, so a block on
##    another member of X's band — which blocks X too (CR 702.22h) — was
##    refused: "Grizzly Bears must block Crashing Boars if able" while the
##    Bears were blocking the Boars' band. NOW every member of the band a
##    block reaches counts, for Crashing Boars' choice and Lure alike.


var _deaths: Array = []


## False Orders' caster: "you MAY have it block" — this one never does, so
## a removed blocker stays out of the fight.
class NoNewBlock extends DecisionAgent:
	func answer_option(_g: MtgGame, _pid: int, _prompt: String,
			options: Array[String], _hint: int) -> int:
		return options.size() - 1   # "Don't block"


func _hear(e: GameEvent) -> void:
	if e.type == Mtg.EventType.DIES:
		_deaths.append(e.data["instance"])


# ------------------------------------------- 1. blocked by only that one --

func _false_orders_on(blocker: CardInstance) -> void:
	g.set_agent(0, NoNewBlock.new())
	var orders := give_hand(0, "False Orders")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, orders, [TargetRef.card(blocker)]))
	resolve_stack()
	assert_false(g.combat.blocks.has(blocker.id), "control: removed from combat")


## The Giant blocked by the Bears and the Wall; [param gone] takes the
## Bears out of the fight first, then False Orders takes the Wall.
func _blocked_by_two_then(gone: Callable) -> CardInstance:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id, wall.id: giant.id}))
	gone.call(bear)
	assert_true(bear.zone != Mtg.Zone.BATTLEFIELD or not g.combat.blocks.has(bear.id),
		"control: the Bears are out of the fight")
	_false_orders_on(wall)
	assert_true(g.combat.blocked_attackers.has(giant.id),
		"it had become blocked by two creatures this combat, not only by the Wall")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "a blocked Giant with nobody left to fight hits nobody")
	return giant


func test_blocked_by_two_stays_blocked_when_the_first_was_removed_from_combat() -> void:
	# The first blocker regenerated, or lost its own Ydwen Efreet flip.
	_blocked_by_two_then(func(bear: CardInstance) -> void: g.remove_from_combat(bear))


func test_blocked_by_two_stays_blocked_when_the_first_was_bounced() -> void:
	_blocked_by_two_then(func(bear: CardInstance) -> void: g.return_to_hand(bear))


func test_blocked_by_two_stays_blocked_when_the_first_died() -> void:
	_blocked_by_two_then(func(bear: CardInstance) -> void: g.destroy(bear))


func test_an_attacker_blocked_by_one_goes_free() -> void:
	# Control: the printed exception itself.
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	_false_orders_on(wall)
	assert_false(g.combat.blocked_attackers.has(giant.id), "blocked by only the Wall: unblocked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)


func test_an_attacker_blocked_by_two_stays_blocked_by_the_other() -> void:
	# Control: one of two removed, the other still blocking.
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id, wall.id: giant.id}))
	_false_orders_on(wall)
	assert_true(g.combat.blocked_attackers.has(giant.id))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the Bears took the Giant's damage")


# ------------------------------------------- 2. Disintegrate on a token --

func test_disintegrate_exiles_a_token_instead_of_letting_it_die() -> void:
	var token: CardInstance = g.create_token(1,
		CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1).with_subtypes(["saproling"]))[0]
	var spell := give_hand(0, "Disintegrate")
	advance_to_step(Mtg.Step.MAIN1)
	g.event_occurred.connect(_hear)
	var before: int = g.players[1].creatures_to_graveyard_this_turn
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(token)], 2))
	resolve_stack()
	assert_ne(token.zone, Mtg.Zone.BATTLEFIELD, "control: it is gone")
	assert_false(_deaths.has(token), "exiled instead: it never died")
	assert_eq(g.players[1].creatures_to_graveyard_this_turn, before,
		"and never reached a graveyard")


func test_disintegrate_exiles_a_card_too() -> void:
	# Control: the card the replacement was written for.
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Disintegrate")
	advance_to_step(Mtg.Step.MAIN1)
	g.event_occurred.connect(_hear)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_false(_deaths.has(bear))


# ----------------------------------------- 3. must block a band member --

func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func test_crashing_boars_accepts_a_block_on_its_band() -> void:
	var infantry := put_battlefield(0, "Benalish Infantry")   # banding
	var boars := put_battlefield(0, "Crashing Boars")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [infantry.id, boars.id], [[infantry.id, boars.id]]))
	resolve_stack()
	assert_true(boars.cur_must_be_blocked, "control: the Bears were chosen to block the Boars")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_eq(g.declare_blockers(1, {bear.id: infantry.id}), "",
		"blocking the Infantry blocks its whole band, the Boars too (CR 702.22h)")


func test_crashing_boars_still_refuses_no_block() -> void:
	# Control: the requirement still stands.
	var infantry := put_battlefield(0, "Benalish Infantry")
	var boars := put_battlefield(0, "Crashing Boars")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [infantry.id, boars.id], [[infantry.id, boars.id]]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "must block")


func test_a_lure_in_a_band_accepts_a_block_on_another_member() -> void:
	var hero := put_battlefield(0, "Benalish Hero")     # banding
	var bear := put_battlefield(0, "Grizzly Bears")
	var lure := give_hand(0, "Lure")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lure, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, bear.id], [[hero.id, bear.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "must block")
	assert_eq(g.declare_blockers(1, {wall.id: hero.id}), "",
		"the Wall blocking the Hero blocks the lured Bears as well")
