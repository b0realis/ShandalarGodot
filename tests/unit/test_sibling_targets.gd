extends GameTest
## A TARGET STATED RELATIVE TO ANOTHER TARGET of the same spell or ability
## — TargetSpec.sibling_filter.
##
## "Target permanent an opponent controls that shares one of those types
## WITH IT" (Gauntlets of Chaos), "target creature that TARGET WALL blocked
## this turn" (Glyph of Delusion), "target artifact cards from TARGET
## PLAYER's graveyard" (Drafna's Restoration): a requirement no per-ref
## predicate can express, because legality depends on what was chosen for
## an EARLIER slot. The mechanism is pinned here on a SYNTHETIC ability so
## nothing below depends on how any card is written; the three cards are
## pinned in tests/cards/test_fidelity_2026_09_02_sibling_targets.gd.
##
## The contract: the plan judges every slot with the earlier slots' refs
## in hand (TargetPlan._validate) and refuses the whole choice with the
## spec's own WHY word; a check that does NOT know the siblings (a
## per-click "may I aim here?" with no earlier ref) is provisionally
## legal; the same relation is re-judged on resolution (CR 608.2b), so a
## partner that stopped qualifying is an illegal target then.


## Two slots: "target creature" and "target creature in the same tapped
## state as the first". The second effect records what it resolved on.
class MateEffect extends EffectBase:
	var resolved_on: Array = []

	func _init() -> void:
		target_spec = TargetSpec.creature(
				"target creature in the same tapped state as the first") \
			.with_sibling_filter(MateEffect._same_state, "tapped")

	static func _same_state(game: MtgGame, _source: CardInstance,
			candidate: TargetRef, earlier: Array) -> bool:
		var first := game.find_instance(earlier[0].instance_id)
		var mate := game.find_instance(candidate.instance_id)
		return first != null and mate != null and first.tapped == mate.tapped

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		resolved_on.append(target.instance_id)

	func describe() -> String:
		return "note the mate"


class FirstEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target creature")

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass

	func describe() -> String:
		return "the first"


var _mate: MateEffect
var _pairer: CardInstance


func _pairer_data() -> CardData:
	_mate = MateEffect.new()
	return CardData.new("Test Pairer", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", false, [FirstEffect.new(), _mate],
			"Pair target creature with target creature in the same tapped state."))


func before_each() -> void:
	super.before_each()
	_pairer = put_synthetic(0, _pairer_data())


func _pair(a: CardInstance, b: CardInstance) -> String:
	return g.activate_ability(0, _pairer, 0, [TargetRef.card(a), TargetRef.card(b)])


# ------------------------------------------------------------ the plan --

func test_a_pair_that_meets_the_relation_is_accepted() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	assert_ok(_pair(a, b))
	resolve_stack()
	assert_eq(_mate.resolved_on, [b.id])


func test_a_pair_that_breaks_the_relation_is_refused_with_the_specs_word() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	g.tap_permanent(b)
	assert_refused(_pair(a, b), "Illegal target (tapped).")
	assert_true(g.stack.is_empty(), "nothing went on the stack")


func test_the_relation_reads_the_slot_actually_chosen() -> void:
	# Same two bodies, the other way round: the first slot is the tapped
	# one now, so an untapped mate is the mismatch.
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	g.tap_permanent(a)
	assert_refused(_pair(a, b), "Illegal target (tapped).")
	g.tap_permanent(b)
	assert_ok(_pair(a, b))   # both tapped: they match again


func test_without_a_known_sibling_the_check_is_provisional() -> void:
	# A per-click check (the duel screen's) knows no earlier ref, so it
	# cannot judge the relation and must not refuse on it.
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	g.tap_permanent(b)
	var spec: TargetSpec = _mate.target_spec
	assert_true(spec.is_legal(g, TargetRef.card(b), _pairer),
		"no earlier ref: provisionally legal")
	assert_eq(spec.refusal_reason(g, TargetRef.card(b), _pairer, [TargetRef.card(a)]),
		"tapped", "with the sibling known, the relation is judged")


func test_legal_targets_narrows_to_the_partners_of_the_chosen_one() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var c := put_battlefield(1, "Serra Angel")
	g.tap_permanent(c)
	var spec: TargetSpec = _mate.target_spec
	var names: Array = []
	for ref in spec.legal_targets(g, _pairer, [TargetRef.card(a)]):
		names.append(g.find_instance(ref.instance_id).data.card_name)
	assert_eq(names, ["Grizzly Bears", "Hill Giant"],
		"untapped partners only (the first pick itself is left to the no-duplicate rule)")
	names = []
	for ref in spec.legal_targets(g, _pairer):
		names.append(g.find_instance(ref.instance_id).data.card_name)
	assert_eq(names.size(), 3, "unknown sibling: every creature is provisionally legal")
	assert_true(names.has("Serra Angel"))
	assert_true(names.has(b.data.card_name))


# ------------------------------------------------------- on resolution --

func test_a_partner_that_stops_qualifying_is_an_illegal_target_on_resolution() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	assert_ok(_pair(a, b))
	g.tap_permanent(b)   # in response: the mate no longer matches
	resolve_stack()
	assert_eq(_mate.resolved_on, [], "the second slot's ref was illegal (CR 608.2b)")


func test_the_relation_is_judged_against_the_first_slot_even_when_that_one_is_illegal() -> void:
	# The first creature gains shroud in response: ITS ref is illegal, but
	# the second slot's requirement is about the object that was NAMED,
	# and it still holds — so the second effect still resolves.
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	assert_ok(_pair(a, b))
	g.attach_aura_from_anywhere(give_hand(0, "Spectral Cloak"), a, 0)
	g.recalculate()
	assert_true(a.cur_shroud)
	resolve_stack()
	assert_eq(_mate.resolved_on, [b.id])


# ----------------------------------------------------------------- the AI --

func test_the_ai_picks_a_partner_that_meets_the_relation() -> void:
	# A synthetic SPELL with the same two slots, so the AI's spell target
	# picker is the thing under test (AiPlayer._choose_targets).
	var mate := MateEffect.new()
	var data := CardData.new("Test Pairing", "{1}", Mtg.CardType.SORCERY) \
		.spell(FirstEffect.new()).spell(mate).oracle("")
	var inst := CardInstance.new(data, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[0].hand.append(inst)
	var angel := put_battlefield(1, "Serra Angel")   # the AI's first pick: their best
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(giant)   # the only body in the Angel's tapped state is... none
	g.tap_permanent(angel)
	var ai := AiPlayer.new(0)
	var picks = ai._choose_targets(g, inst, 0)
	assert_not_null(picks)
	assert_eq(picks.size(), 2)
	assert_eq(picks[0].instance_id, angel.id, "the best creature first")
	assert_eq(picks[1].instance_id, giant.id, "then the only partner in its tapped state")
	assert_ne(picks[1].instance_id, bear.id)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, inst, picks))   # what the AI picked, the engine accepts
