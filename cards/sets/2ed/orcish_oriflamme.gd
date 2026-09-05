extends CardScript
## Orcish Oriflamme — {3}{R} — Enchantment — (2ed, uncommon)
## Oracle: Attacking creatures you control get +1/+0.
##
## Implementation: a conditional global static — the boost reads live
## combat state (combat.attackers) each recalculation, so it appears when
## attackers are declared and vanishes when combat ends (the engine
## recalculates at both moments). mage-go: BoostControlledCreatures(1, 0,
## IsAttacking).


func build() -> CardData:
	return CardData.new("Orcish Oriflamme", "{3}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply, "Attacking creatures you control get +1/+0.")) \
		.oracle("Attacking creatures you control get +1/+0.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature() and game.combat.attackers.has(inst.id):
			inst.cur_power += 1
