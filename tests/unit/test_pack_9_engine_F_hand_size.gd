extends GameTest
## Pack 9 engine follow-up F — statics that READ A HAND SIZE ("creatures
## with power greater than the number of cards in your hand can't attack",
## Ensnaring Bridge; "power and toughness are each equal to the number of
## cards in your hand", Maro) are continuous effects: their answer changes
## the moment the hand does (CR 611.3a). The engine recomputes
## characteristics after board changes, and a draw, a discard or a cast
## is not one — so the Bridge judged an attack by the hand it saw at the
## last recalculation, and a Maro whose hand was emptied stood at its old
## size through the next state-based check.
##
## The engine now (a) recalculates as attackers and as blockers are
## declared, whatever changed before, and (b) recalculates after a card is
## drawn, discarded or cast outside a resolution (a resolution already
## ends with one). The Bridge-shaped statics here are SYNTHETIC and carry
## no listener of their own; Maro is the real card.

const PRESETS := ["modern", "fifth"]


static func _bridge() -> CardData:
	return CardData.new("Test Bridge", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_no_big_attackers,
			"Creatures with power greater than the number of cards in your hand can't attack.") \
			.reading_pt())


static func _no_big_attackers(g: MtgGame, s: CardInstance) -> void:
	var n := g.players[s.controller_id].hand.size()
	for i in g.all_battlefield():
		if i.is_creature() and i.cur_power > n:
			i.cur_cant_attack = true


## "Creatures with power greater than the number of cards in your hand
## can't block." — the blocking twin.
static func _wall_of_hands() -> CardData:
	return CardData.new("Test Block Bridge", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_no_big_blockers,
			"Creatures with power greater than the number of cards in your hand can't block.") \
			.reading_pt())


static func _no_big_blockers(g: MtgGame, s: CardInstance) -> void:
	var n := g.players[s.controller_id].hand.size()
	for i in g.all_battlefield():
		if i.is_creature() and i.cur_power > n:
			i.cur_cant_block_filter = _any


static func _any(_attacker: CardInstance) -> bool:
	return true


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_edition(preset)
	advance_to_step(Mtg.Step.MAIN1)


## Put a card in [param pid]'s hand WITHOUT any engine event — the
## "something else changed the hand" case the declaration must still read.
func _slip_into_hand(pid: int) -> CardInstance:
	return give_hand(pid, "Forest")


# ------------------------------------------------------------- attacking --

func test_the_attack_ban_reads_the_hand_as_attackers_are_declared() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_synthetic(0, _bridge())
		var bear := put_battlefield(0, "Grizzly Bears")
		_slip_into_hand(0)
		g.recalculate()
		assert_true(bear.cur_cant_attack, "%s: power 2 > 1 card" % preset)
		_slip_into_hand(0)
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [bear.id]))
		assert_true(g.combat.attackers.has(bear.id), "%s: two cards now: it may attack" % preset)


func test_the_attack_ban_refuses_after_the_hand_shrank() -> void:
	_fresh("modern")
	put_synthetic(0, _bridge())
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := _slip_into_hand(0)
	_slip_into_hand(0)
	g.recalculate()
	assert_false(bear.cur_cant_attack, "precondition: 2 cards")
	g.players[0].hand.erase(a)   # gone without an event
	a.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(a)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))


func test_a_draw_updates_the_ban_at_once() -> void:
	_fresh("modern")
	put_synthetic(0, _bridge())
	var bear := put_battlefield(0, "Grizzly Bears")
	_slip_into_hand(0)
	g.recalculate()
	assert_true(bear.cur_cant_attack)
	g.draw_cards(0, 1)
	assert_false(bear.cur_cant_attack, "two cards after the draw")


# -------------------------------------------------------------- blocking --

func test_the_block_ban_reads_the_hand_as_blockers_are_declared() -> void:
	_fresh("modern")
	var attacker := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _wall_of_hands())
	var blocker := put_battlefield(1, "Grizzly Bears")
	_slip_into_hand(1)
	g.recalculate()
	assert_true(blocker.cur_cant_block_filter.is_valid(), "precondition: power 2 > 1 card")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	_slip_into_hand(1)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	assert_true(g.combat.blocks.has(blocker.id), "two cards now: it may block")


# ----------------------------------------------------------------- Maro --

func _maro(pid: int) -> CardInstance:
	var was := Settings.enabled_card_packs().has("pack-8")
	CardPacks.set_enabled("pack-8", true)
	var maro := put_battlefield(pid, "Maro")
	if not was:
		CardPacks.set_enabled("pack-8", false)
	return maro


func test_maro_dies_when_a_discard_empties_the_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var maro := _maro(0)
		var cards := [_slip_into_hand(0), _slip_into_hand(0)]
		g.recalculate()
		assert_eq([maro.cur_power, maro.cur_toughness], [2, 2], preset)
		g.discard_cards(0, cards)
		assert_eq([maro.cur_power, maro.cur_toughness], [0, 0],
			"%s: its size follows the hand at once" % preset)
		g.check_state_based_actions()
		assert_eq(maro.zone, Mtg.Zone.GRAVEYARD, "%s: a 0/0 (CR 704.5f)" % preset)


func test_maro_grows_with_a_draw() -> void:
	_fresh("modern")
	var maro := _maro(0)
	_slip_into_hand(0)
	g.recalculate()
	g.draw_cards(0, 2)
	assert_eq([maro.cur_power, maro.cur_toughness], [3, 3])


func test_maro_dies_when_its_last_card_is_cast() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var maro := _maro(0)
		var bolt := give_hand(0, "Lightning Bolt")
		g.recalculate()
		assert_eq(maro.cur_toughness, 1, preset)
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
		assert_eq(maro.zone, Mtg.Zone.GRAVEYARD,
			"%s: no cards in hand, 0/0, gone before anyone gets priority" % preset)
		resolve_stack()
		assert_eq(g.players[1].life, 17, preset)
