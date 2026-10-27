extends GameTest
## The bug campaign c12, the lead's card-side end of the engine fixes:
## El-Hajjâj and Spirit Link trigger once for all the damage their creature
## deals at once (h3-8, the per-source damage event); Spell Blast's refusal
## names the mana value (h3-21); Eye for an Eye names a stolen spell's caster
## in the 1997 damage window as Reflect Damage does (h3-6).


func _triggers_from(card_name: String) -> int:
	var n := 0
	for item in g.stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.description.begins_with(card_name):
			n += 1
	return n


func test_spirit_link_on_a_double_blocked_creature_triggers_once() -> void:
	g.rules.free_damage_assignment = false   # lethal to each in order: two packets
	var wurm := put_battlefield(0, "Craw Wurm")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var link := give_hand(0, "Spirit Link")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, link, [TargetRef.card(wurm)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: wurm.id, b.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_triggers_from("Spirit Link"), 1, "one damage event, one trigger (CR 603.2c)")
	resolve_stack()
	assert_eq(g.players[0].life, 26, "for the 6 it dealt in all")


func test_el_hajjaj_dealing_damage_twice_at_once_triggers_once() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var hajjaj := put_battlefield(0, "El-Hajjâj")
	var x := put_battlefield(1, "Hill Giant")
	g.begin_simultaneous()
	g.deal_damage(hajjaj, TargetRef.card(x), 1)
	g.deal_damage(hajjaj, TargetRef.player(1), 2)
	g.end_simultaneous()
	assert_eq(_triggers_from("El-Hajjâj"), 1)
	resolve_stack()
	assert_eq(g.players[0].life, 23)


func test_spell_blast_refuses_with_the_mana_value() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var fireball := give_hand(0, "Fireball")
	var blast := give_hand(0, "Spell Blast")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(bear)], 3))
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_refused(g.cast_spell(0, blast, [TargetRef.card(fireball)], 3), "mana value")
