extends GameTest
## SHADOW (Pack 9 engine package E1) — the Tempest block's evasion keyword,
## pinned on synthetic cards:
##
## * M_SHADOW — `Mtg.Keyword.SHADOW`, printed, granted until end of turn or
##   by a static, lost until end of turn. CR 702.28b: "A creature with
##   shadow can't be blocked by creatures without shadow, and a creature
##   without shadow can't be blocked by creatures with shadow."
##   [method CombatState.block_illegality] checks both directions on LIVE
##   keywords; 702.28c (several instances are redundant) is the keyword
##   list's ordinary de-duplication.
## * M_SHADOW_ASTHOUGH — "can block creatures with shadow as though it had
##   shadow" (Heartwood Dryad, Wall of Diffusion):
##   [member CardInstance.cur_blocks_shadow], set by
##   [method CombatState.blocks_shadow]. It lifts only the attacker-has-
##   shadow check; the creature still blocks ordinary creatures normally.
## * M_LKI_KEYWORDS — "whenever a creature with shadow dies" (Dauthi Ghoul):
##   [member CardInstance.last_keywords], the live keywords at the moment it
##   left the battlefield (CR 608.2h / 603.10a), read with
##   [method CardInstance.had_keyword].
##
## A block, once declared, is not undone by a later gain or loss of shadow
## (CR 506.4 / 509.1h): legality is checked at the declaration only.


# ------------------------------------------------------------ the cards --

static func _creature(name: String, power: int, toughness: int,
		keywords: Array = [], cost := "{1}{B}") -> CardData:
	return CardData.new(name, cost, Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


static func _shade(name := "Test Shade", power := 2, toughness := 1,
		more: Array = [], cost := "{1}{B}") -> CardData:
	var keywords: Array = [Mtg.Keyword.SHADOW]
	keywords.append_array(more)
	return _creature(name, power, toughness, keywords, cost)


## Heartwood Dryad's shape: "can block creatures with shadow as though it
## had shadow".
static func _dryad() -> CardData:
	return _creature("Test Dryad", 2, 4, [], "{1}{G}") \
		.static_ability(CombatState.blocks_shadow())


## "All creatures able to block this creature do so" (Lure, as a printed
## static on the creature itself).
static func _lured_shade() -> CardData:
	return _shade("Test Lured Shade", 2, 2) \
		.static_ability(StaticAbility.new(_lure_self, "All creatures able to block this creature do so."))


static func _lured_bear() -> CardData:
	return _creature("Test Lured Bear", 2, 2) \
		.static_ability(StaticAbility.new(_lure_self, "All creatures able to block this creature do so."))


static func _lure_self(_g: MtgGame, source: CardInstance) -> void:
	source.cur_must_be_blocked = true


## "Creatures your opponents control lose all abilities" (Titania's Song's
## flag, CR 613 layer 6) — one-sided, so the attacking shade keeps its
## shadow (losing all abilities strips keywords too) and only the
## defender's "as though" permission is in question.
static func _song() -> CardData:
	return CardData.new("Test Song", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence, "Creatures your opponents control lose all abilities.") \
			.silencing_abilities())


static func _silence(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.controller_id != source.controller_id:
			inst.cur_abilities_silenced = true


## "Creatures you control have shadow" — a static GRANT (layer 6).
static func _cloak() -> CardData:
	return CardData.new("Test Shadow Cloak", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_grant_shadow, "Creatures you control have shadow."))


static func _grant_shadow(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature() and not inst.cur_keywords.has(Mtg.Keyword.SHADOW):
			inst.cur_keywords.append(Mtg.Keyword.SHADOW)


## Dauthi Ghoul's shape: "Whenever a creature with shadow dies, put a +1/+1
## counter on this creature" — the dead creature's LAST KNOWN keywords.
static func _ghoul() -> CardData:
	return _shade("Test Ghoul", 1, 1) \
		.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _grow,
			"Whenever a creature with shadow dies, put a +1/+1 counter on this creature.",
			_shadow_died))


static func _shadow_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and dead.had_keyword(Mtg.Keyword.SHADOW)


static func _grow(game: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "+1/+1")


# ------------------------------------------------------------- helpers --

func _why(blocker: CardInstance, attacker: CardInstance) -> String:
	return CombatState.block_illegality(g, blocker, attacker, blocker.controller_id)


func _to_blockers(attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


# ============================================================ the enum ==

## Appended at the END: keyword ordinals are serialised (saved games, the
## SGManalink view protocol validates against `Mtg.Keyword.size()`), so
## every earlier value keeps its number.
func test_shadow_is_appended_after_every_older_keyword() -> void:
	assert_eq(Mtg.Keyword.FLANKING, 13, "the last Pack 8 keyword keeps its ordinal")
	assert_eq(Mtg.Keyword.SHADOW, 14)
	assert_eq(Mtg.Keyword.size(), 15)
	assert_eq(String(Mtg.Keyword.keys()[Mtg.Keyword.SHADOW]), "SHADOW")


# ====================================================== the block matrix ==

func test_a_creature_without_shadow_cannot_block_a_shadow_creature() -> void:
	var shade := put_synthetic(0, _shade())
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_string_contains(_why(bear, shade), "shadow")


func test_a_shadow_creature_cannot_block_a_creature_without_shadow() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shade := put_synthetic(1, _shade())
	assert_string_contains(_why(shade, bear), "shadow")


func test_two_shadow_creatures_block_each_other() -> void:
	var a := put_synthetic(0, _shade("Test Shade A"))
	var b := put_synthetic(1, _shade("Test Shade B"))
	assert_eq(_why(b, a), "")
	assert_eq(_why(a, b), "", "both directions")


## Shadow is evasion ON TOP of the others (CR 702.28b adds a restriction,
## it does not replace one): a flying shade needs a blocker with shadow AND
## flying or reach.
func test_flying_and_shadow_both_apply() -> void:
	var flyer := put_synthetic(0, _shade("Test Winged Shade", 2, 2, [Mtg.Keyword.FLYING]))
	var ground_shade := put_synthetic(1, _shade("Test Ground Shade"))
	var winged_shade := put_synthetic(1, _shade("Test Other Winged Shade", 1, 1, [Mtg.Keyword.FLYING]))
	var reach_shade := put_synthetic(1, _shade("Test Reach Shade", 1, 3, [Mtg.Keyword.REACH]))
	var bird := put_synthetic(1, _creature("Test Bird", 1, 1, [Mtg.Keyword.FLYING]))
	assert_string_contains(_why(ground_shade, flyer), "flying")
	assert_eq(_why(winged_shade, flyer), "")
	assert_eq(_why(reach_shade, flyer), "")
	assert_string_contains(_why(bird, flyer), "shadow", "a flyer without shadow can't")


func test_fear_and_shadow_both_apply() -> void:
	var dread := put_synthetic(0, _shade("Test Dread Shade", 2, 2, [Mtg.Keyword.FEAR]))
	var green_shade := put_synthetic(1, _shade("Test Green Shade", 1, 1, [], "{1}{G}"))
	var black_shade := put_synthetic(1, _shade("Test Black Shade", 1, 1, [], "{1}{B}"))
	var black_bear := put_synthetic(1, _creature("Test Black Bear", 2, 2, [], "{1}{B}"))
	assert_string_contains(_why(green_shade, dread), "fear")
	assert_eq(_why(black_shade, dread), "")
	assert_string_contains(_why(black_bear, dread), "shadow")


func test_landwalk_and_shadow_both_apply() -> void:
	var walker := put_synthetic(0, _shade("Test Swamp Shade", 2, 2) \
		.with_landwalk(["swamp"]))
	var shade := put_synthetic(1, _shade("Test Blocker Shade"))
	assert_eq(_why(shade, walker), "", "no swamp: an ordinary shadow block")
	put_battlefield(1, "Swamp")
	assert_string_contains(_why(shade, walker), "swampwalk")


func test_protection_and_shadow_both_apply() -> void:
	var monk := put_synthetic(0, _shade("Test Monk", 2, 1, [], "{W}{W}") \
		.with_protection_from(Mtg.ManaColor.B))
	var black_shade := put_synthetic(1, _shade("Test Black Shade", 1, 1, [], "{1}{B}"))
	var white_shade := put_synthetic(1, _shade("Test White Shade", 1, 1, [], "{1}{W}"))
	assert_string_contains(_why(black_shade, monk), "protection")
	assert_eq(_why(white_shade, monk), "")


## Multiple instances are redundant (CR 702.28c): a printed shade that
## gains shadow again still blocks a shade, and loses it with one loss.
func test_two_instances_of_shadow_are_one() -> void:
	var shade := put_synthetic(0, _shade())
	g.continuous.add_until_eot_keywords(shade.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_eq(shade.cur_keywords.count(Mtg.Keyword.SHADOW), 1)
	var bear := put_battlefield(1, "Grizzly Bears")
	g.continuous.add_until_eot_loss(shade.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_false(shade.has_keyword(Mtg.Keyword.SHADOW))
	assert_eq(_why(bear, shade), "")


# ================================================ "as though it had shadow" ==

func test_an_as_though_blocker_blocks_shadow_and_ordinary_creatures() -> void:
	var shade := put_synthetic(0, _shade())
	var bear := put_battlefield(0, "Grizzly Bears")
	var dryad := put_synthetic(1, _dryad())
	assert_true(dryad.cur_blocks_shadow)
	assert_false(dryad.has_keyword(Mtg.Keyword.SHADOW), "it does not HAVE shadow")
	assert_eq(_why(dryad, shade), "")
	assert_eq(_why(dryad, bear), "", "it still blocks a creature without shadow")


## The permission is ONLY about shadow: a flying shade is still out of reach
## of a ground-bound Dryad.
func test_an_as_though_blocker_still_needs_flying_for_a_flying_shade() -> void:
	var flyer := put_synthetic(0, _shade("Test Winged Shade", 2, 2, [Mtg.Keyword.FLYING]))
	var dryad := put_synthetic(1, _dryad())
	assert_string_contains(_why(dryad, flyer), "flying")


## A shadow creature blocking: the attacker without shadow is out of reach
## whatever the "as though" permission says — it is read only for the
## attacker-has-shadow direction.
func test_a_shadow_blocker_with_the_permission_still_cannot_block_a_bear() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shade := put_synthetic(1, _shade("Test Odd Shade", 1, 3) \
		.static_ability(CombatState.blocks_shadow()))
	assert_true(shade.cur_blocks_shadow)
	assert_string_contains(_why(shade, bear), "shadow")


func test_a_silenced_as_though_blocker_loses_the_permission() -> void:
	var shade := put_synthetic(0, _shade())
	var dryad := put_synthetic(1, _dryad())
	put_synthetic(0, _song())
	assert_false(dryad.cur_blocks_shadow, "a live value, rebuilt each pass")
	assert_true(shade.has_keyword(Mtg.Keyword.SHADOW), "the Song is one-sided")
	assert_string_contains(_why(dryad, shade), "shadow")


func test_a_face_down_shade_has_no_shadow() -> void:
	var shade := put_synthetic(0, _shade())
	shade.face_down = true
	g.recalculate()
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_false(shade.has_keyword(Mtg.Keyword.SHADOW))
	assert_eq(_why(bear, shade), "")


# ============================================== through the declaration ==

func test_the_engine_refuses_a_bear_blocking_a_shade_and_changes_nothing() -> void:
	var shade := put_synthetic(0, _shade())
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blockers([shade.id])
	assert_refused(g.declare_blockers(1, {bear.id: shade.id}), "shadow")
	assert_true(g.awaiting_blockers, "the refusal changed nothing")
	assert_true(g.combat.blocks.is_empty())
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18, "unblocked")


func test_shade_blocks_shade_and_they_trade() -> void:
	var a := put_synthetic(0, _shade("Test Shade A", 2, 2))
	var b := put_synthetic(1, _shade("Test Shade B", 2, 2))
	run_combat([a.id], {b.id: a.id})
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


func test_the_dryad_blocks_a_shade_through_the_engine() -> void:
	var shade := put_synthetic(0, _shade("Test Shade", 2, 2))
	var dryad := put_synthetic(1, _dryad())
	run_combat([shade.id], {dryad.id: shade.id})
	assert_eq(shade.zone, Mtg.Zone.GRAVEYARD, "a 2/4 kills the 2/2 shade")
	assert_eq(dryad.zone, Mtg.Zone.BATTLEFIELD)


# ===================================================== granted and lost ==

## Shadow Rift's shape: granted until end of turn BEFORE blockers, the
## attacker can't be blocked by creatures without shadow — and it wears
## off at cleanup.
func test_shadow_granted_before_blocks_makes_the_attacker_evasive() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_true(bear.has_keyword(Mtg.Keyword.SHADOW))
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {wall.id: bear.id}), "shadow")
	assert_ok(g.declare_blockers(1, {}))
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.SHADOW), "until end of turn")


## A static grant counts the same way (layer 6, live keywords).
func test_shadow_granted_by_a_static() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, _cloak())
	assert_true(bear.has_keyword(Mtg.Keyword.SHADOW))
	assert_string_contains(_why(other, bear), "shadow")


## Reality Anchor's shape: an attacker that LOSES shadow before blockers
## can be blocked normally (and can no longer be blocked by a shade).
func test_shadow_lost_before_blocks_lets_a_normal_creature_block() -> void:
	var shade := put_synthetic(0, _shade("Test Shade", 2, 2))
	var bear := put_battlefield(1, "Grizzly Bears")
	var other := put_synthetic(1, _shade("Test Other Shade", 1, 1))
	_to_blockers([shade.id])
	g.continuous.add_until_eot_loss(shade.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_string_contains(_why(other, shade), "shadow")
	assert_ok(g.declare_blockers(1, {bear.id: shade.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(shade.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


## CR 506.4 / 509.1h: once blocks are declared, GAINING shadow does not
## undo them — the bear stays blocked and deals its damage to the wall.
func test_shadow_gained_after_blocks_changes_nothing() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blockers([bear.id])
	assert_ok(g.declare_blockers(1, {giant.id: bear.id}))
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_true(g.combat.is_blocking(giant.id, bear.id))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the giant's block still kills it")
	assert_eq(giant.damage, 2, "and took the bear's damage")
	assert_eq(g.players[1].life, 20, "nothing got through")


## ... nor does LOSING it: a shade blocked by a shade stays blocked.
func test_shadow_lost_after_blocks_changes_nothing() -> void:
	var a := put_synthetic(0, _shade("Test Shade A", 2, 2))
	var b := put_synthetic(1, _shade("Test Shade B", 1, 3))
	_to_blockers([a.id])
	assert_ok(g.declare_blockers(1, {b.id: a.id}))
	g.continuous.add_until_eot_loss(a.id, [Mtg.Keyword.SHADOW])
	g.continuous.add_until_eot_loss(b.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(b.damage, 2)
	assert_eq(g.players[1].life, 20)


# ================================================================ Lure ==

## Lure on a shade obliges only the creatures ABLE to block it — the
## shades (CR 509.1c defers to the restriction).
func test_a_lured_shade_obliges_only_shadow_blockers() -> void:
	var lured := put_synthetic(0, _lured_shade())
	var bear := put_battlefield(1, "Grizzly Bears")
	var shade := put_synthetic(1, _shade("Test Defending Shade", 1, 1))
	_to_blockers([lured.id])
	assert_refused(g.declare_blockers(1, {}), "Test Defending Shade")
	assert_refused(g.declare_blockers(1, {bear.id: lured.id}), "shadow")
	assert_ok(g.declare_blockers(1, {shade.id: lured.id}))
	assert_false(g.combat.blocks.has(bear.id), "the bear was never asked")


## ... and Lure on an ordinary creature never asks a shade.
func test_a_lured_bear_does_not_ask_a_shade() -> void:
	var lured := put_synthetic(0, _lured_bear())
	var shade := put_synthetic(1, _shade("Test Defending Shade", 1, 1))
	_to_blockers([lured.id])
	assert_ok(g.declare_blockers(1, {}))
	assert_false(g.combat.blocks.has(shade.id))


# ================================================ last known keywords ==

func test_the_ghoul_counts_a_shade_that_dies() -> void:
	var ghoul := put_synthetic(0, _ghoul())
	var shade := put_synthetic(1, _shade())
	g.destroy(shade)
	resolve_stack()
	assert_true(shade.had_keyword(Mtg.Keyword.SHADOW))
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1)


## Granted shadow counts: it is the creature's LAST KNOWN keywords that the
## trigger reads (CR 608.2h), not its printed ones.
func test_the_ghoul_counts_a_creature_whose_shadow_was_granted() -> void:
	var ghoul := put_synthetic(0, _ghoul())
	var bear := put_battlefield(1, "Grizzly Bears")
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	g.destroy(bear)
	resolve_stack()
	assert_true(bear.had_keyword(Mtg.Keyword.SHADOW))
	assert_false(bear.has_keyword(Mtg.Keyword.SHADOW), "a card in the graveyard has no grant")
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1)


func test_the_ghoul_ignores_a_creature_without_shadow() -> void:
	var ghoul := put_synthetic(0, _ghoul())
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear)
	resolve_stack()
	assert_false(bear.had_keyword(Mtg.Keyword.SHADOW))
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 0)


## A shade that LOST its shadow before dying is not "a creature with
## shadow" as it dies.
func test_the_ghoul_ignores_a_shade_that_lost_its_shadow() -> void:
	var ghoul := put_synthetic(0, _ghoul())
	var shade := put_synthetic(1, _shade())
	g.continuous.add_until_eot_loss(shade.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	g.destroy(shade)
	resolve_stack()
	assert_false(shade.had_keyword(Mtg.Keyword.SHADOW))
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 0)


func test_a_shadow_token_counts_too() -> void:
	var ghoul := put_synthetic(0, _ghoul())
	var token: CardInstance = g.create_token(1, _shade("Test Shade Token", 1, 1))[0]
	g.destroy(token)
	resolve_stack()
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1)


## The snapshot is primary state: a search that kills a shade and unwinds
## puts `last_keywords` back too (the journal records the departing
## object whole), and so does a GameSnapshot.
func test_undo_restores_last_keywords() -> void:
	var shade := put_synthetic(1, _shade())
	assert_true(shade.last_keywords.is_empty())
	var mark := g.make_mark()
	g.destroy(shade)
	assert_true(shade.had_keyword(Mtg.Keyword.SHADOW))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(shade.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(shade.last_keywords.is_empty(), "the journal put it back")
	var snap := GameSnapshot.take(g)
	g.destroy(shade)
	assert_true(shade.had_keyword(Mtg.Keyword.SHADOW))
	snap.restore()
	assert_true(shade.last_keywords.is_empty(), "the snapshot put it back")
	assert_eq(shade.zone, Mtg.Zone.BATTLEFIELD)


# ======================================================== both presets ==

## Shadow did not change between the 1997 rules and today's (it was printed
## in 1997 with the same wording): the matrix is the same under "fifth".
func test_the_fifth_edition_preset_blocks_the_same_way() -> void:
	g.rules.set_edition("fifth")
	var shade := put_synthetic(0, _shade())
	var bear := put_battlefield(1, "Grizzly Bears")
	var other := put_synthetic(1, _shade("Test Other Shade"))
	var dryad := put_synthetic(1, _dryad())
	assert_string_contains(_why(bear, shade), "shadow")
	assert_eq(_why(other, shade), "")
	assert_eq(_why(dryad, shade), "")
	_to_blockers([shade.id])
	assert_refused(g.declare_blockers(1, {bear.id: shade.id}), "shadow")
	assert_ok(g.declare_blockers(1, {other.id: shade.id}))


# ============================================================= the AI ==

## Evaluator: shadow is evasion close to flying's worth, discounted for the
## creature's near-uselessness on defence (it blocks only shadow).
func test_the_evaluator_prices_shadow_as_evasion_with_a_defensive_discount() -> void:
	var vanilla := put_synthetic(0, _creature("Test Vanilla", 2, 1))
	var shade := put_synthetic(0, _shade("Test Shade", 2, 1))
	var flyer := put_synthetic(0, _creature("Test Flyer", 2, 1, [Mtg.Keyword.FLYING]))
	var v := Evaluator.permanent_value(vanilla)
	var s := Evaluator.permanent_value(shade)
	var f := Evaluator.permanent_value(flyer)
	assert_gt(s, v, "evasion is worth something")
	assert_lt(s, f + 0.01, "but no more than a flyer that also defends")
	var wall_shade := put_synthetic(0, _shade("Test Tough Shade", 1, 4))
	var tough := put_synthetic(0, _creature("Test Tough", 1, 4))
	assert_lt(Evaluator.permanent_value(wall_shade) - Evaluator.permanent_value(tough),
		s - v, "a big toughness is worth less on a creature that can't block")
	assert_gt(Evaluator.card_value(shade.data), Evaluator.card_value(vanilla.data))
