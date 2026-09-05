extends CardScript
## Tor Wauki — {2}{B}{B}{R} — Legendary Creature — Human Archer — 3/3 — (leg, uncommon)
## Oracle: {T}: Tor Wauki deals 2 damage to target attacking or blocking
##         creature.
##
## Implementation: the archer cycle's middle — two damage, and because the
## shot happens before combat damage it finishes off anything his own
## blockers wound. Same combat-aware target filter as D'Avenant Archer.


func build() -> CardData:
	var shot := DamageEffect.new(2)
	shot.target_spec = TargetSpec.creature("target attacking or blocking creature") \
		.with_game_filter(_in_combat)
	return CardData.new("Tor Wauki", "{2}{B}{B}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "archer"]) \
		.activated(ActivatedAbility.new(
			"", true, [shot],
			"{T}: Tor Wauki deals 2 damage to target attacking or blocking creature.")) \
		.oracle("{T}: Tor Wauki deals 2 damage to target attacking or blocking creature.")


static func _in_combat(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id) or game.combat.blocks.has(inst.id)
