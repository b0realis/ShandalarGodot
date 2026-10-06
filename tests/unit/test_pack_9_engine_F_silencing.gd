extends GameTest
## Pack 9 engine follow-up F — "LOSES ALL ABILITIES" AND THE GRANTS THAT
## COME AFTER IT (Humility, Titania's Song; CR 613.1f, 613.7, 613.8a).
##
## Lead ruling (2026-10-06, faithful to CR 613.7): an ability granted LATER
## than an ability-removing effect works. Package E5 put the removal on the
## layer-6 clock; this file pins the parts that were still missing:
##
## 1. A TRIGGER granted after the removal fires. The dispatcher
##    ([method MtgGame.dispatch_event]), the state-trigger check
##    ([method MtgGame._check_state_triggers]) and the mana planner
##    ([method ManaPlanner._source_row]) skip only the PRINTED triggers of
##    a silenced permanent (CR 613.8a: removing an ability changes the
##    existence of the creature's own abilities, whatever the timestamps).
## 2. The older statics that GRANT an ability and did not say so
##    ([method StaticAbility.changing_abilities]) ran after layer 6 and
##    survived even an EARLIER Humility: Spectral Cloak, Equinox, Torrent
##    of Lava, the Wards, Energy Flux; and the self-shroud statics declare
##    their layer too.
## 3. Animate Artifact's creature type is a layer-4 effect, so Humility
##    (which applies after layer 4) sees the animated artifact as a
##    creature.
##
## Humility here is the two statics the card prints, built from the
## ready-made E5 API (the card itself is a Pack 9 batch's file).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## Ice Age (Breath of Dreams, Dreams of the Dead), Homelands (Serra
## Bestiary), Alliances (Deadly Insect) and the Mirage block (Torrent of
## Lava, Pendrell Mists, Jolrael's Centaur, Ward of Lights).
const PACKS := ["pack-3", "pack-4", "pack-5", "pack-8"]
var _were_enabled: Array[String] = []


func before_all() -> void:
	_were_enabled = Settings.enabled_card_packs()
	for id in PACKS:
		CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in PACKS:
		if not _were_enabled.has(id):
			CardPacks.set_enabled(id, false)


# ------------------------------------------------------------ definitions --

static func _creature(_g: MtgGame, _s: CardInstance, inst: CardInstance) -> bool:
	return inst.is_creature()


## "All creatures lose all abilities and have base power and toughness 1/1."
static func _humility() -> CardData:
	return CardData.new("Test Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.removing_all_abilities(_creature,
			"All creatures lose all abilities.")) \
		.static_ability(StaticAbility.base_pt_for(_creature, 1, 1,
			"All creatures have base power and toughness 1/1."))


## "Creatures have 'When this creature has no mark counter on it, put a
## mark counter on it.'" — a granted STATE trigger.
static func _state_granter() -> CardData:
	var trig := TriggeredAbility.new(Mtg.EventType.STATE_CHECK, _mark,
		"When this creature has no mark counter on it, put a mark counter on it.",
		_unmarked)
	return CardData.new("Test State Granter", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_grant_to_creatures.bind(trig),
			"Creatures have \"When this creature has no mark counter on it, put a mark counter on it.\"") \
			.changing_abilities().granting_triggers([Mtg.EventType.STATE_CHECK]))


static func _unmarked(_g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return int(s.counters.get("mark", 0)) == 0


static func _mark(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if g.is_present(s):
		g.add_counters(s, "mark", 1)


## "Creatures have 'Whenever a Forest is tapped for mana, its controller
## adds an additional {G}.'" — a granted triggered MANA ability.
static func _mana_granter() -> CardData:
	var trig := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _extra_green,
		"Whenever a Forest is tapped for mana, its controller adds an additional {G}.",
		_forest_tapped).as_mana_trigger()
	trig.mana_bonus_subtype = "forest"
	trig.mana_bonus_color = G
	trig.mana_bonus_amount = 1
	return CardData.new("Test Mana Granter", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_grant_to_creatures.bind(trig),
			"Creatures have \"Whenever a Forest is tapped for mana, its controller adds an additional {G}.\"") \
			.changing_abilities().granting_triggers([Mtg.EventType.TAPPED_FOR_MANA]))


static func _forest_tapped(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return land != null and land.has_subtype("forest")


static func _extra_green(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	g.players[int(e.data.player)].mana_pool.add(G, 1)


static func _grant_to_creatures(game: MtgGame, _source: CardInstance,
		trig: TriggeredAbility) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and not inst.cur_triggered_abilities.has(trig):
			inst.cur_triggered_abilities.append(trig)


## A creature with a PRINTED upkeep trigger ("you gain 1 life").
static func _printed_upkeep_creature() -> CardData:
	return CardData.new("Test Upkeep Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2) \
		.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _gain_one,
			"At the beginning of your upkeep, you gain 1 life.", _own_upkeep))


static func _own_upkeep(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data["player"]) == s.controller_id


static func _gain_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.adjust_life(s.controller_id, 1)


func _enchant_named(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	var aura := _make_instance(pid, card_name)
	g._put_on_battlefield(aura, pid, host)
	return aura


## Pass until [param pid]'s NEXT upkeep has begun (its triggers are on the
## stack, nothing resolved yet).
func _to_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) \
			and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid, "%d's upkeep" % pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func _stack_holds_trigger_of(inst: CardInstance) -> bool:
	for item in g.stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.card == inst:
			return true
	return false


func _flagged(card_name: String) -> bool:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	for ability in data.static_abilities:
		if ability.changes_abilities:
			return true
	return false


# =============== 1. TRIGGERS GRANTED AFTER THE SILENCER FIRE ===============

func test_a_tax_granted_after_humility_triggers() -> void:
	# Pendrell Mists entered after Humility: its grant is the later effect
	# (CR 613.7), so the bear has the tax and it triggers.
	var bear := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _humility())
	put_battlefield(0, "Pendrell Mists")
	assert_true(bear.cur_abilities_silenced, "precondition: Humility reached it")
	_to_upkeep_of(1)
	assert_true(_stack_holds_trigger_of(bear), "the later grant triggers")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "nothing to pay with: sacrificed")


func test_a_tax_granted_before_humility_is_removed() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Pendrell Mists")
	put_synthetic(0, _humility())
	_to_upkeep_of(1)
	assert_false(_stack_holds_trigger_of(bear), "Humility is the later effect: no tax")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_cumulative_upkeep_granted_after_humility_triggers() -> void:
	# Breath of Dreams: "Green creatures have cumulative upkeep {1}."
	var bear := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _humility())
	put_battlefield(0, "Breath of Dreams")
	_to_upkeep_of(1)
	assert_true(_stack_holds_trigger_of(bear), "the later grant's cumulative upkeep triggers")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "an age counter it could not pay for")


func test_cumulative_upkeep_granted_before_humility_is_removed() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Breath of Dreams")
	put_synthetic(0, _humility())
	_to_upkeep_of(1)
	assert_false(_stack_holds_trigger_of(bear))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_dreams_of_the_dead_under_humility_grants_a_working_upkeep() -> void:
	# The grant is a floating effect created as the ability resolves —
	# after Humility entered — so the raised creature has cumulative upkeep.
	put_synthetic(1, _humility())
	var dreams := put_battlefield(0, "Dreams of the Dead")
	var knight := give_hand(0, "White Knight")
	g.discard_cards(0, [knight])
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	add_mana(0, U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, dreams, 0, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(knight.cur_abilities_silenced)
	_to_upkeep_of(0)
	assert_true(_stack_holds_trigger_of(knight), "the later grant triggers")


func test_dreams_of_the_dead_before_humility_loses_the_upkeep() -> void:
	var dreams := put_battlefield(0, "Dreams of the Dead")
	var knight := give_hand(0, "White Knight")
	g.discard_cards(0, [knight])
	add_mana(0, U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, dreams, 0, [TargetRef.card(knight)]))
	resolve_stack()
	put_synthetic(1, _humility())
	_to_upkeep_of(0)
	assert_false(_stack_holds_trigger_of(knight), "Humility is the later effect")


func test_a_printed_trigger_stays_silent_whatever_the_order() -> void:
	# CR 613.8a: Humility removes the creature's own trigger even when the
	# creature entered after it.
	put_synthetic(0, _humility())
	var bear := put_synthetic(1, _printed_upkeep_creature())
	assert_true(bear.cur_abilities_silenced)
	_to_upkeep_of(1)
	assert_false(_stack_holds_trigger_of(bear), "a printed trigger does nothing")
	assert_eq(g.players[1].life, 20)


func test_a_state_trigger_granted_after_humility_triggers() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _humility())
	put_synthetic(0, _state_granter())
	g.check_state_based_actions()
	assert_true(_stack_holds_trigger_of(bear), "the later state trigger is checked")
	resolve_stack()
	assert_eq(int(bear.counters.get("mark", 0)), 1)


func test_a_granted_state_trigger_works_without_humility() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _state_granter())
	g.check_state_based_actions()
	assert_true(_stack_holds_trigger_of(bear))
	resolve_stack()
	assert_eq(int(bear.counters.get("mark", 0)), 1)


func test_a_state_trigger_granted_before_humility_is_removed() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _state_granter())
	put_synthetic(0, _humility())
	g.check_state_based_actions()
	assert_false(_stack_holds_trigger_of(bear), "Humility is later: nothing to check")
	resolve_stack()
	assert_eq(int(bear.counters.get("mark", 0)), 0)


func test_a_mana_trigger_granted_after_humility_adds_its_mana() -> void:
	put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	put_synthetic(1, _humility())
	put_synthetic(1, _mana_granter())
	var amount := -1
	for row in ManaPlanner.sources(g, 0):
		if row[0] == forest:
			amount = int(row[3])
	assert_eq(amount, 2, "the planner counts the later grant's bonus")
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(G), 2, "and the dispatcher adds it")


func test_a_mana_trigger_granted_before_humility_adds_nothing() -> void:
	put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	put_synthetic(1, _mana_granter())
	put_synthetic(1, _humility())
	var amount := -1
	for row in ManaPlanner.sources(g, 0):
		if row[0] == forest:
			amount = int(row[3])
	assert_eq(amount, 1)
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(G), 1)


# ================ 2. OLDER GRANTS DECLARE THEIR LAYER (CR 613.1f) ================

# ---- activated abilities: Equinox, Torrent of Lava

func test_an_equinox_older_than_humility_is_removed() -> void:
	put_battlefield(0, "Living Lands")
	var forest := put_battlefield(0, "Forest")
	_enchant_named(0, "Equinox", forest)
	assert_eq(forest.cur_activated_abilities.size(), 1, "precondition: the granted ability")
	put_synthetic(1, _humility())
	assert_true(forest.cur_abilities_silenced, "a Living Lands Forest is a creature")
	assert_eq(forest.cur_activated_abilities.size(), 0,
		"the Equinox's grant is older than Humility: removed")


func test_an_equinox_newer_than_humility_grants_its_ability() -> void:
	put_battlefield(0, "Living Lands")
	var forest := put_battlefield(0, "Forest")
	put_synthetic(1, _humility())
	_enchant_named(0, "Equinox", forest)
	assert_true(forest.cur_abilities_silenced)
	assert_eq(forest.cur_activated_abilities.size(), 1, "the later grant survives")


func test_torrent_of_lavas_shield_is_a_layer_six_grant() -> void:
	# Granted in layer 6, the {T} shield is there for Serra Bestiary to
	# deny ("its activated abilities with {T} in their costs can't be
	# activated" — the engine drops them from the live list after layer 6).
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_enchant_named(1, "Serra Bestiary", bear)
	var torrent := give_hand(0, "Torrent of Lava")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, R, 3)
	assert_ok(g.cast_spell(0, torrent, [], 1))
	assert_eq(giant.cur_activated_abilities.size(), 1, "each creature has the shield")
	assert_eq(bear.cur_activated_abilities.size(), 0,
		"but the Bestiary's creature can't activate a {T} ability")
	assert_true(CardRegistry.get_card("Torrent of Lava").stack_static_abilities[0].changes_abilities)


func test_torrent_of_lava_cast_under_humility_still_grants() -> void:
	put_synthetic(1, _humility())
	var bear := put_battlefield(1, "Grizzly Bears")
	var torrent := give_hand(0, "Torrent of Lava")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, R, 3)
	assert_ok(g.cast_spell(0, torrent, [], 1))
	assert_true(bear.cur_abilities_silenced)
	assert_eq(bear.cur_activated_abilities.size(), 1, "the spell's grant is the later effect")


# ---- shroud: Spectral Cloak, and the printed self-shroud statics

func test_a_spectral_cloak_older_than_humility_is_removed() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant_named(0, "Spectral Cloak", bear)
	assert_true(bear.cur_shroud, "precondition: untapped, so shrouded")
	put_synthetic(1, _humility())
	assert_false(bear.cur_shroud, "Humility is the later effect")


func test_a_spectral_cloak_newer_than_humility_shrouds() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	_enchant_named(0, "Spectral Cloak", bear)
	assert_true(bear.cur_abilities_silenced)
	assert_true(bear.cur_shroud, "the later grant survives")


func test_printed_shroud_statics_declare_their_layer() -> void:
	assert_true(_flagged("Deadly Insect"), "Deadly Insect's shroud is layer 6")
	assert_true(_flagged("Jolrael's Centaur"), "Jolrael's Centaur's shroud is layer 6")
	assert_true(_flagged("Spectral Cloak"))
	assert_true(_flagged("Equinox"))
	put_synthetic(1, _humility())
	var insect := put_battlefield(0, "Deadly Insect")
	assert_false(insect.cur_shroud, "its own shroud: gone whatever the order (CR 613.8a)")


# ---- protection: the Wards

func test_a_ward_older_than_humility_loses_its_protection() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := _enchant_named(0, "White Ward", bear)
	assert_ne(bear.cur_protection & W, 0, "precondition: protection from white")
	put_synthetic(1, _humility())
	assert_eq(bear.cur_protection & W, 0, "Humility is the later effect")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "the Ward stays on")


func test_a_ward_newer_than_humility_protects() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	var ward := _enchant_named(0, "White Ward", bear)
	assert_true(bear.cur_abilities_silenced)
	assert_ne(bear.cur_protection & W, 0, "the later grant survives")
	g.check_state_based_actions()
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "and still does not remove its own Ward")


func test_every_ward_declares_its_layer() -> void:
	for card_name in ["White Ward", "Blue Ward", "Black Ward", "Red Ward", "Green Ward",
			"Ward of Lights"]:
		assert_true(_flagged(card_name), "%s's protection is layer 6" % card_name)


# ---- triggers: Energy Flux (its pinned pair lives in test_fidelity_2026_09_02_flux.gd)

func test_energy_flux_declares_its_layer() -> void:
	assert_true(_flagged("Energy Flux"))


func test_an_energy_flux_older_than_titanias_song_taxes_nothing() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Energy Flux")
	put_battlefield(0, "Titania's Song")
	assert_true(ring.cur_abilities_silenced)
	assert_true(ring.cur_triggered_abilities.is_empty(), "the Song is the later effect")
	_to_upkeep_of(1)
	assert_false(_stack_holds_trigger_of(ring))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


# ============== 3. ANIMATE ARTIFACT'S TYPE IS LAYER 4 ==============

func test_humility_sees_an_artifact_animate_artifact_made_a_creature() -> void:
	var rod := put_battlefield(0, "Rod of Ruin")   # mana value 4
	_enchant_named(0, "Animate Artifact", rod)
	assert_true(rod.is_creature())
	assert_eq([rod.cur_power, rod.cur_toughness], [4, 4], "precondition")
	put_synthetic(1, _humility())
	assert_true(rod.is_creature())
	assert_true(rod.cur_abilities_silenced, "a creature after layer 4: Humility reaches it")
	assert_eq(rod.cur_activated_abilities.size(), 0, "the Rod's ability is gone")
	assert_eq([rod.cur_power, rod.cur_toughness], [1, 1], "Humility's 1/1 is the later 7b effect")


func test_an_animate_artifact_newer_than_humility_sets_the_size() -> void:
	var rod := put_battlefield(0, "Rod of Ruin")
	put_synthetic(1, _humility())
	_enchant_named(0, "Animate Artifact", rod)
	assert_true(rod.cur_abilities_silenced)
	assert_eq([rod.cur_power, rod.cur_toughness], [4, 4],
		"Animate Artifact's mana-value size is the later 7b effect")


func test_animate_artifact_splits_its_two_layers() -> void:
	var statics := CardRegistry.get_card("Animate Artifact").static_abilities
	assert_eq(statics.size(), 2, "a layer-4 type and a layer-7b size (CR 613.1)")
	assert_true(statics[0].changes_types, "the creature type is layer 4")
	assert_false(statics[0].sets_base_pt)
	assert_true(statics[1].sets_base_pt, "the size is layer 7b")
	assert_false(statics[1].changes_types)


func test_animate_artifact_on_an_artifact_creature_does_nothing() -> void:
	var golem := put_battlefield(0, "Clockwork Beast")
	var before := [golem.cur_power, golem.cur_toughness]
	_enchant_named(0, "Animate Artifact", golem)
	assert_eq([golem.cur_power, golem.cur_toughness], before,
		"already a creature: the Aura adds nothing")


# --- Granted DIES triggers in a simultaneous batch (lead, 2026-10-06) ------
## "Creatures have 'Whenever another creature dies, its controller gains 1
## life.'" Creatures that die TOGETHER hear each other through the departure
## batch's pre-event snapshot (MtgGame._death_listener_snapshot, CR 603.10a),
## which must skip only a silenced creature's PRINTED triggers, as the
## dispatcher does (MtgGame.trigger_silenced, CR 613.7).
## (Known engine limit, no card in the pool: a trigger GRANTED to a creature
## about "this creature dies" is not seen by that creature as it leaves —
## its look-back sees only its printed triggers. docs/pack-9-tempest-block.md.)
static func _dies_granter() -> CardData:
	var trig := TriggeredAbility.new(Mtg.EventType.DIES, _gain_one,
		"Whenever another creature dies, its controller gains 1 life.", _another_died)
	return CardData.new("Test Dies Granter", "{1}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_grant_to_creatures.bind(trig),
			"Creatures have \"Whenever another creature dies, its controller gains 1 life.\"") \
			.changing_abilities().granting_triggers([Mtg.EventType.DIES]))


static func _another_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and dead != s


func _two_die_together(humility_first: bool, humility := true) -> int:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	if humility and humility_first: put_synthetic(0, _humility())
	put_synthetic(0, _dies_granter())
	if humility and not humility_first: put_synthetic(0, _humility())
	g.recalculate()
	var life := g.players[1].life
	a.damage = 2
	b.damage = 2
	g.check_state_based_actions()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "both die in one state-based check")
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	return g.players[1].life - life


func test_a_granted_another_dies_trigger_hears_a_batch() -> void:
	assert_eq(_two_die_together(false, false), 2, "each hears the other's death")


func test_a_dies_trigger_granted_after_humility_hears_a_batch() -> void:
	assert_eq(_two_die_together(true), 2, "the later grant survives Humility in the snapshot")


func test_a_dies_trigger_granted_before_humility_is_silent_in_a_batch() -> void:
	assert_eq(_two_die_together(false), 0, "an older grant is removed by Humility")
