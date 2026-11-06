extends RefCounted
## Urza's Legacy (_combat, Pack 10). Combat restrictions, requirements and combat-damage effects.
##
## Viashino Bey: "If this creature attacks, all creatures you control attack
## if able" is a CONDITIONAL attack requirement (CR 508.1d) on every other
## creature its controller controls, keyed to the Bey being among the
## declared attackers — Magnetic Web's shape (Pack 9 E4,
## CombatState.add_attack_requirement; cards/sets/tmp/_combat.gd). It is
## rebuilt each recalculation, so a silenced Bey imposes nothing, and a
## creature that can't attack (summoning sick, tapped, defender) is not
## asked to (CR 508.1d: "if able"). tests/cards/test_pack_10_B4_black_red.gd
## pins it.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Viashino Bey":
			c.static_ability(StaticAbility.new(_bey,
				"If this creature attacks, all creatures you control attack if able."))
		_: return false
	return true


static func _bey(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i != s and i.is_creature() and not i.phased_out:
			CombatState.add_attack_requirement(i, s, _bey_attacks.bind(s.id),
				"%s attacks" % s.data.card_name)


## The Bey (this object, by id) is among the creatures being declared.
static func _bey_attacks(_g: MtgGame, declared: Array, bey_id: int) -> bool:
	for inst in declared:
		if inst is CardInstance and (inst as CardInstance).id == bey_id:
			return true
	return false
