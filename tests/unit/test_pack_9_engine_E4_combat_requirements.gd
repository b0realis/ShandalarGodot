extends GameTest
## COMBAT REQUIREMENTS (Pack 9 engine package E4), pinned on synthetic
## cards:
##
## * M_MUST_BLOCK — "this creature blocks each combat if able" (Watchdog;
##   "All creatures block each combat if able", Invasion Plans):
##   [member CardInstance.cur_must_block], a static's live value, set by
##   [method CombatState.blocks_each_combat]; "that creature blocks this
##   turn if able" (Provoke): [member CardInstance.must_block_this_turn_any],
##   set by [method MtgGame.require_block_this_turn], cleared at cleanup.
##   CR 509.1c: the declaration must obey as many requirements as possible
##   without violating a restriction, and no requirement makes a player pay
##   a blocking cost (509.1d). The engine refuses a declaration that leaves
##   an able creature at home ([method CombatDeclaration.must_block_error]
##   from [method MtgGame.declare_blockers]); the AI's
##   [method CombatDeclaration.repair_blocks] writes the cheapest legal
##   forced block in.
## * M_COND_ATTACK_REQ — "if a creature with a magnet counter on it attacks,
##   all creatures with magnet counters on them attack if able" (Magnetic
##   Web): a PREDICATE form of Ekundu Cyclops' conditional requirement,
##   [member CardInstance.cur_attack_requirements] added by
##   [method CombatState.add_attack_requirement] and honoured by
##   [method CombatDeclaration.attack_error] / `repair_attacks` (CR 508.1d).

const CombatDeclaration := preload("res://engine/core/combat_declaration.gd")
const F := preload("res://cards/sets/fem/_rules.gd")


# ------------------------------------------------------------ the cards --

static func _creature(name: String, power: int, toughness: int,
		keywords: Array = [], cost := "{1}{G}") -> CardData:
	return CardData.new(name, cost, Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


static func _watchdog(name := "Test Watchdog") -> CardData:
	return CardData.new(name, "{3}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 2).static_ability(CombatState.blocks_each_combat())


## "All creatures block each combat if able. The attacking player chooses
## how each creature blocks each combat." (Invasion Plans)
static func _plans() -> CardData:
	return CardData.new("Test Plans", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_plans_rule,
			"All creatures block each combat if able. The attacking player chooses how each creature blocks each combat."))


static func _plans_rule(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_must_block = true
	game.block_chooser_override = game.active_player


## "Untap target creature you don't control. That creature blocks this
## turn if able." (Provoke, without its "Draw a card")
static func _provoke() -> CardData:
	return CardData.new("Test Provoke", "{1}{G}", Mtg.CardType.INSTANT) \
		.spell(F.Action.new(_provoke_resolve, "untap target creature; it blocks this turn if able",
			TargetSpec.creature()))


static func _provoke_resolve(game: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var inst := game.find_instance(t.instance_id)
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.untap_permanent(inst)
	game.require_block_this_turn(inst)


## Caverns of Despair's cap: "No more than one creature can block each
## combat."
static func _cap() -> CardData:
	return CardData.new("Test Cap", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_cap_rule, "No more than one creature can block each combat."))


static func _cap_rule(game: MtgGame, _source: CardInstance) -> void:
	game.max_blockers = 1


static func _lured(name := "Test Lured Bear") -> CardData:
	return _creature(name, 2, 2) \
		.static_ability(StaticAbility.new(_lure_self, "All creatures able to block this creature do so."))


static func _lure_self(_g: MtgGame, source: CardInstance) -> void:
	source.cur_must_be_blocked = true


## "Can't be blocked unless the defending player pays {1}" — a blocking
## COST (CR 509.1d), never required.
static func _taxed() -> CardData:
	return _creature("Test Taxed Bear", 2, 2) \
		.static_ability(StaticAbility.new(_tax_self, "Blocking this creature costs {1}."))


static func _tax_self(_g: MtgGame, source: CardInstance) -> void:
	source.cur_blocked_by_tax = 1


static func _menace(name := "Test Menace") -> CardData:
	return _creature(name, 2, 2) \
		.static_ability(StaticAbility.new(_menace_self, "Can't be blocked except by two or more creatures."))


static func _menace_self(_g: MtgGame, source: CardInstance) -> void:
	source.cur_min_blockers = 2


## Magnetic Web's attack half, on synthetic counters.
static func _web() -> CardData:
	return CardData.new("Test Web", "{2}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_web_rule,
			"If a creature with a magnet counter on it attacks, all creatures with magnet counters on them attack if able."))


static func _web_rule(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and int(inst.counters.get("magnet", 0)) > 0:
			CombatState.add_attack_requirement(inst, source, _a_magnet_attacks,
				"a creature with a magnet counter on it attacks")


static func _a_magnet_attacks(_game: MtgGame, declared: Array) -> bool:
	for inst in declared:
		if int((inst as CardInstance).counters.get("magnet", 0)) > 0:
			return true
	return false


static func _cyclops() -> CardData:
	return _creature("Test Cyclops", 3, 4) \
		.static_ability(CombatState.attacks_with_others())


static func _song() -> CardData:
	return CardData.new("Test Song", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence, "Creatures lose all abilities.") \
			.silencing_abilities())


static func _silence(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		inst.cur_abilities_silenced = true


# ------------------------------------------------------------- helpers --

func _to_blockers(attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


func _magnetise(inst: CardInstance) -> void:
	g.add_counters(inst, "magnet")
	g.recalculate()


# ===================================================== blocks each combat ==

func test_the_watchdog_must_block_an_attacker_it_can_block() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	assert_true(dog.cur_must_block)
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {}), "Test Watchdog")
	assert_true(g.awaiting_blockers, "the refusal changed nothing")
	assert_true(g.combat.blocks.is_empty())
	assert_ok(g.declare_blockers(1, {dog.id: bear.id}))


func test_the_watchdog_may_choose_which_attacker_it_blocks() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	_to_blockers([bear.id, other.id])
	assert_ok(g.declare_blockers(1, {dog.id: other.id}))


func test_no_requirement_when_every_block_is_illegal() -> void:
	var bird := put_synthetic(0, _creature("Test Bird", 1, 1, [Mtg.Keyword.FLYING]))
	var shade := put_synthetic(0, _creature("Test Shade", 1, 1, [Mtg.Keyword.SHADOW]))
	put_synthetic(1, _watchdog())
	_to_blockers([bird.id, shade.id])
	# flying and shadow are restrictions
	assert_ok(g.declare_blockers(1, {}))


func test_no_requirement_to_pay_a_blocking_cost() -> void:
	var taxed := put_synthetic(0, _taxed())
	put_synthetic(1, _watchdog())
	put_battlefield(1, "Forest")
	_to_blockers([taxed.id])
	# CR 509.1d: costs are never required
	assert_ok(g.declare_blockers(1, {}))


func test_a_tapped_watchdog_is_excused() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	dog.tapped = true
	_to_blockers([bear.id])
	assert_ok(g.declare_blockers(1, {}))


func test_a_silenced_watchdog_has_no_requirement() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	put_synthetic(0, _song())
	assert_false(dog.cur_must_block, "a live value, rebuilt each pass")
	_to_blockers([bear.id])
	assert_ok(g.declare_blockers(1, {}))


## A Lure is a requirement too: a creature able to block the lured
## attacker must block IT; blocking the other attacker obeys the Watchdog's
## own requirement but breaks the Lure's, and the most requirements must be
## obeyed (CR 509.1c).
func test_a_requirement_beside_a_lure() -> void:
	var lured := put_synthetic(0, _lured())
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	_to_blockers([lured.id, bear.id])
	assert_refused(g.declare_blockers(1, {dog.id: bear.id}), "Test Lured Bear")
	assert_ok(g.declare_blockers(1, {dog.id: lured.id}))


## A cap on blockers is a RESTRICTION (CR 509.1c): with room for one, the
## Watchdog — not a volunteer — must be the one, and two Watchdogs are
## satisfied by either.
func test_a_blocker_cap_beats_the_requirement_only_when_spent_on_requirements() -> void:
	put_synthetic(0, _cap())
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog("Test Watchdog A"))
	var volunteer := put_battlefield(1, "Grizzly Bears")
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {volunteer.id: bear.id}), "Test Watchdog A")
	assert_ok(g.declare_blockers(1, {dog.id: bear.id}))


func test_two_watchdogs_under_a_cap_of_one() -> void:
	put_synthetic(0, _cap())
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_synthetic(1, _watchdog("Test Watchdog A"))
	put_synthetic(1, _watchdog("Test Watchdog B"))
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {}))
	assert_ok(g.declare_blockers(1, {a.id: bear.id}))


## "Can't be blocked except by two or more creatures": the Watchdog alone
## cannot make that block, so it is excused — unless a second creature can
## join it, which the most-requirements rule then asks for.
func test_a_menace_attacker_and_the_watchdog() -> void:
	var menace := put_synthetic(0, _menace())
	put_synthetic(1, _watchdog())
	_to_blockers([menace.id])
	# one creature can't block it
	assert_ok(g.declare_blockers(1, {}))


func test_a_menace_attacker_the_watchdog_and_a_partner() -> void:
	var menace := put_synthetic(0, _menace())
	var dog := put_synthetic(1, _watchdog())
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blockers([menace.id])
	assert_refused(g.declare_blockers(1, {}), "Test Watchdog")
	assert_ok(g.declare_blockers(1, {dog.id: menace.id, bear.id: menace.id}))


func test_the_fifth_edition_preset_enforces_it_too() -> void:
	g.rules.set_edition("fifth")
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {}), "Test Watchdog")
	assert_ok(g.declare_blockers(1, {dog.id: bear.id}))


# ================================================ blocks this turn (Provoke) ==

func test_provoke_untaps_and_orders_a_block() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	giant.tapped = true
	var provoke := give_synthetic(0, _provoke())
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, provoke, [TargetRef.card(giant)]))
	resolve_stack()
	assert_false(giant.tapped)
	assert_true(giant.must_block_this_turn_any)
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {}), "Hill Giant")
	assert_ok(g.declare_blockers(1, {giant.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_provoke_wears_off_at_cleanup() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	g.require_block_this_turn(giant)
	assert_true(giant.must_block_this_turn_any)
	advance_to_next_turn()
	assert_false(giant.must_block_this_turn_any, "this turn only (CR 514.2)")


func test_provoke_excuses_a_creature_that_cannot_block() -> void:
	var bird := put_synthetic(0, _creature("Test Bird", 1, 1, [Mtg.Keyword.FLYING]))
	var giant := put_battlefield(1, "Hill Giant")
	g.require_block_this_turn(giant)
	_to_blockers([bird.id])
	assert_ok(g.declare_blockers(1, {}))


func test_provoke_ends_with_a_zone_change() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	g.require_block_this_turn(giant)
	g.return_to_hand(giant)
	assert_false(giant.must_block_this_turn_any, "a new object (CR 400.7)")


func test_a_search_rewinds_the_provoke_order() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var mark := g.make_mark()
	g.require_block_this_turn(giant)
	assert_true(giant.must_block_this_turn_any)
	g.unmake_to(mark)
	g.end_search()
	assert_false(giant.must_block_this_turn_any)


# ============================================================ Invasion Plans ==

func test_invasion_plans_the_attacker_declares_every_able_block() -> void:
	put_synthetic(1, _plans())
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	assert_true(a.cur_must_block)
	_to_blockers([bear.id])
	assert_eq(g.block_chooser(), 0, "the attacking player chooses")
	assert_refused(g.declare_blockers(1, {a.id: bear.id, b.id: bear.id}), "designated")
	assert_refused(g.declare_blockers(0, {a.id: bear.id}), "Llanowar Elves")
	assert_ok(g.declare_blockers(0, {a.id: bear.id, b.id: bear.id}))
	assert_eq(g.combat.blockers_of(bear.id).size(), 2)


func test_invasion_plans_with_the_ai_choosing_for_the_defender() -> void:
	put_synthetic(1, _plans())
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	_to_blockers([bear.id])
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.act(g)
	assert_false(g.awaiting_blockers, "the AI made a legal declaration")
	assert_false(g.game_over)
	assert_true(g.combat.blocks.has(a.id))
	assert_true(g.combat.blocks.has(b.id))


# ============================================================ the AI repair ==

func test_repair_writes_the_forced_block_in() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	_to_blockers([bear.id])
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1, {})
	assert_eq(repaired.get(dog.id, []), [bear.id])
	assert_ok(g.declare_blockers(1, repaired))


## The cheapest forced block for the defender: the attacker it survives.
func test_repair_prefers_the_block_the_watchdog_survives() -> void:
	var elf := put_battlefield(0, "Llanowar Elves")
	var giant := put_battlefield(0, "Hill Giant")
	var dog := put_synthetic(1, _watchdog())
	_to_blockers([giant.id, elf.id])
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1, {})
	assert_eq(repaired.get(dog.id, []), [elf.id])


func test_repair_makes_room_under_a_cap() -> void:
	put_synthetic(0, _cap())
	var bear := put_battlefield(0, "Grizzly Bears")
	var dog := put_synthetic(1, _watchdog())
	var volunteer := put_battlefield(1, "Grizzly Bears")
	_to_blockers([bear.id])
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1, {volunteer.id: bear.id})
	assert_true(repaired.has(dog.id))
	assert_false(repaired.has(volunteer.id))
	assert_ok(g.declare_blockers(1, repaired))


func test_repair_adds_a_partner_for_a_menace_attacker() -> void:
	var menace := put_synthetic(0, _menace())
	var dog := put_synthetic(1, _watchdog())
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blockers([menace.id])
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1, {})
	assert_true(repaired.has(dog.id))
	assert_true(repaired.has(bear.id))
	assert_ok(g.declare_blockers(1, repaired))


func test_the_ai_defender_obeys_the_watchdog() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var dog := put_synthetic(1, _watchdog())
	_to_blockers([giant.id])
	var ai := AiPlayer.new(1, AiProfile.wizard())
	ai.act(g)
	assert_false(g.awaiting_blockers)
	assert_false(g.game_over, "no concession")
	assert_true(g.combat.is_blocking(dog.id, giant.id), "the forced block, made")


# ============================================================ Magnetic Web ==

func test_a_magnet_attacker_drags_the_other_magnet_creatures_along() -> void:
	put_synthetic(1, _web())
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	var plain := put_battlefield(0, "Llanowar Elves")
	_magnetise(a)
	_magnetise(b)
	assert_eq(b.cur_attack_requirements.size(), 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [a.id]), "Hill Giant")
	assert_true(g.awaiting_attackers, "the refusal changed nothing")
	assert_refused(g.declare_attackers(0, [a.id, plain.id]), "Hill Giant")
	assert_ok(g.declare_attackers(0, [a.id, b.id]))


func test_no_magnet_attacker_no_requirement() -> void:
	put_synthetic(1, _web())
	var a := put_battlefield(0, "Grizzly Bears")
	var plain := put_battlefield(0, "Llanowar Elves")
	_magnetise(a)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	# the condition never arose
	assert_ok(g.declare_attackers(0, [plain.id]))


func test_nobody_attacking_is_legal_under_the_web() -> void:
	put_synthetic(1, _web())
	var a := put_battlefield(0, "Grizzly Bears")
	_magnetise(a)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))


func test_an_unable_magnet_creature_is_excused() -> void:
	put_synthetic(1, _web())
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	_magnetise(a)
	_magnetise(b)
	b.tapped = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id]))


func test_a_silenced_web_imposes_nothing() -> void:
	put_synthetic(1, _web())
	put_synthetic(0, _song())
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	_magnetise(a)
	_magnetise(b)
	assert_true(b.cur_attack_requirements.is_empty())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id]))


func test_repair_attacks_brings_the_other_magnet_creatures() -> void:
	put_synthetic(1, _web())
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	var plain := put_battlefield(0, "Llanowar Elves")
	_magnetise(a)
	_magnetise(b)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var repaired: Array = CombatDeclaration.repair_attacks(g, 0, [a.id])
	assert_true(repaired.has(a.id) and repaired.has(b.id), "the plan, completed")
	assert_eq(CombatDeclaration.repair_attacks(g, 0, [plain.id]), [plain.id],
		"a plan without a magnet creature stands")
	assert_ok(g.declare_attackers(0, repaired))


## Ekundu Cyclops' conditional requirement is unchanged beside the Web.
func test_the_cyclops_and_the_web_together() -> void:
	put_synthetic(1, _web())
	var cyclops := put_synthetic(0, _cyclops())
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	_magnetise(a)
	_magnetise(b)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [a.id, b.id]), "Test Cyclops")
	assert_refused(g.declare_attackers(0, [a.id, cyclops.id]), "Hill Giant")
	# the Cyclops alone triggers no magnet
	assert_ok(g.declare_attackers(0, [cyclops.id]))
