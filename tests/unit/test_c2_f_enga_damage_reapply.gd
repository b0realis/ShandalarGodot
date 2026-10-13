extends GameTest
## CR 616.1e, the "then the rule is applied again" half (campaign 2026-10-12,
## b3-2). After one replacement or prevention effect modifies a damage
## event, the affected player (or the affected object's controller) looks
## again at EVERY effect that would apply to the modified event — including
## one that did not apply before. MtgGame._land_damage_impl used to build
## its candidate list once and only ever drop entries from it, so a
## threshold that the event crossed only after Furnace of Rath doubled it
## was never consulted: Ali from Cairo at 4 life let a doubled Lightning
## Bolt take its controller to -2, and Forethought Amulet let a doubled
## Shock through at 4.
##
## And the other half of the same rule, CR 614.5: an effect that has
## already modified the event does not get a second turn at it — the
## rebuilt list leaves out what was already applied.
##
## Both rules presets are checked; the 1997 one only moves the life check
## to the end of the phase, which is why these tests read the life total.

const PACKS := ["pack-9"]
const PRESETS := ["modern_mana_burn", "fifth"]


## Answers the CR 616.1 ordering question with the index the test parked
## (-1 = the engine's hint) and records every question it was asked.
class Orderer extends DecisionAgent:
	var take := -1
	var asked: Array[String] = []

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(" | ".join(options))
		if take < 0 or take >= options.size():
			return hint
		return take


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _fresh(preset: String) -> void:
	super.before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)


## P1 aims [param spell] at P0 with Furnace of Rath on P1's side.
func _burn_p0(spell: String) -> void:
	put_battlefield(1, "Furnace of Rath")
	var card := give_hand(1, spell)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, card, [TargetRef.player(0)]))
	resolve_stack()


# Ali from Cairo at 4 life: the Bolt's 3 would leave 1, so Ali does not
# apply to the event as cast. Furnace doubles it to 6 — and now it does.
func test_ali_from_cairo_applies_to_the_doubled_bolt() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(0, "Ali from Cairo")
		g.players[0].life = 4
		_burn_p0("Lightning Bolt")
		assert_eq(g.players[0].life, 1, "%s: Ali holds the doubled Bolt at 1" % preset)
		assert_false(g.game_over, "%s: P0 is still alive" % preset)


# Forethought Amulet: "3 or more ... deals 2 instead". A Shock is 2 and is
# not touched — until Furnace makes it 4.
func test_forethought_amulet_caps_the_doubled_shock() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(0, "Forethought Amulet")
		_burn_p0("Shock")
		assert_eq(g.players[0].life, 18, "%s: the doubled Shock is capped at 2" % preset)


# CR 614.5: both apply to a Bolt from the start. Taking the Amulet first
# caps it at 2, Furnace doubles that to 4 — and the Amulet, which has
# already had its turn, does NOT cap it again (the rebuilt list must not
# offer it twice). Taking Furnace first: 6, then the Amulet: 2.
#
# Under the 1997 rules nobody is asked (the owner's ruling of 2026-10-12,
# `RulesOptions.damage_effects_fixed_order`; tests/unit/
# test_c2_f_order_damage_order.gd): the fixed order takes the Amulet
# first, and the doubled 4 is still not capped a second time.
func test_an_effect_already_applied_is_not_offered_again() -> void:
	for preset in PRESETS:
		var asked: bool = preset != "fifth"
		_fresh(preset)
		var orderer := Orderer.new()
		orderer.take = 0
		g.set_agent(0, orderer)
		put_battlefield(0, "Forethought Amulet")
		_burn_p0("Lightning Bolt")
		assert_eq(orderer.asked.size(), 1 if asked else 0,
			"%s: one question, two candidates — or none under 1997" % preset)
		assert_eq(g.players[0].life, 16, "%s: Amulet, then Furnace — 4" % preset)

		_fresh(preset)
		orderer = Orderer.new()
		orderer.take = 1
		g.set_agent(0, orderer)
		put_battlefield(0, "Forethought Amulet")
		_burn_p0("Lightning Bolt")
		assert_eq(g.players[0].life, 18 if asked else 16,
			"%s: Furnace, then Amulet — 2; the fixed order under 1997 — 4" % preset)


# The creature branch walks the same rule. A test shield that only stops
# damage of 4 or more does not apply to a Bolt — until Furnace doubles it.
func test_a_creature_s_shield_applies_after_the_doubling() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var wurm := put_battlefield(0, "Craw Wurm")   # 6/4
		assert_true(g.add_damage_effect({
			"desc": "Test shield (4 or more)", "kind": &"prevent",
			"victims": [wurm], "filter": _four_or_more}) >= 0)
		_burn_creature(wurm)
		assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "%s: the shield caught the doubled Bolt" % preset)
		assert_eq(wurm.damage, 0, "%s: nothing marked" % preset)


# Control: without the doubling the shield never applies and the Bolt is
# marked as cast — the rebuild adds what applies, nothing else.
func test_without_the_doubling_the_threshold_shield_stays_out() -> void:
	_fresh("modern_mana_burn")
	var wurm := put_battlefield(0, "Craw Wurm")
	g.add_damage_effect({
		"desc": "Test shield (4 or more)", "kind": &"prevent",
		"victims": [wurm], "filter": _four_or_more})
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(wurm.damage, 3)


func _burn_creature(victim: CardInstance) -> void:
	put_battlefield(1, "Furnace of Rath")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(victim)]))
	resolve_stack()


static func _four_or_more(_game: MtgGame, packet: DamagePacket) -> bool:
	return packet.remaining() >= 4
