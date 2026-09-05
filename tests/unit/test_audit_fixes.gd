extends GameTest
## Engine-level pins from the mage-go scrutiny audit (docs/audit-vs-mage-go.md):
## ability self-targeting (an ability MAY target its own source — only a
## spell can't target itself), regeneration's tap feeding conditional
## statics immediately, and counters applying AFTER dynamic-P/T statics
## (CR 613.4 layer 7b before 7d — Nightmare with a +1/+1 counter).


# ------------------------------------------------------ ability self-target --

func test_ability_can_target_its_own_source() -> void:
	# Samite Healer may shield ITSELF (CR: only a spell can't target itself;
	# an ability targeting its own source is legal — mage-go allows it too).
	var healer := put_battlefield(0, "Samite Healer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, healer, 0, [TargetRef.card(healer)]))
	resolve_stack()
	assert_eq(healer.prevention, 1, "the healer shielded itself")
	# The shield actually works: a 1-damage ping bounces off.
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(healer), 1)
	assert_eq(healer.damage, 0, "1 damage prevented")
	assert_eq(healer.zone, Mtg.Zone.BATTLEFIELD)


func test_spell_cannot_target_itself() -> void:
	# A Counterspell aimed at its own cast is refused (a spell never
	# targets itself — it isn't even on the stack while targets are chosen).
	var cs := give_hand(0, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(0, cs, [TargetRef.card(cs)]), "Illegal target")


# ------------------------------------- regeneration tap feeds statics --

func test_regeneration_tap_immediately_updates_conditional_statics() -> void:
	# Castle boosts UNTAPPED creatures. Regenerating taps the creature —
	# the Castle bonus must vanish in the same breath, not a recalc later.
	put_battlefield(0, "Castle")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(bear.cur_toughness, 4, "2 + Castle's +0/+2 while untapped")
	var ward := give_hand(0, "Death Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1)
	g.destroy(bear, true)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped, "regeneration taps (CR 701.15)")
	assert_eq(bear.cur_toughness, 2, "tapped — Castle bonus gone immediately")


# ------------------------------------------- counters vs dynamic-P/T statics --

func test_counters_survive_dynamic_pt_statics() -> void:
	# Nightmare's characteristic-defining static SETS P/T to the swamp
	# count (layer 7b); +1/+1 counters apply AFTER that (layer 7d), so a
	# counter on a Nightmare must not be wiped by the recalculation.
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var mare := put_battlefield(0, "Nightmare")
	assert_eq(mare.cur_power, 2, "two swamps")
	g.add_counters(mare, "+1/+1", 1)
	assert_eq(mare.cur_power, 3, "2 swamps + the counter (7b before 7d)")
	assert_eq(mare.cur_toughness, 3)
