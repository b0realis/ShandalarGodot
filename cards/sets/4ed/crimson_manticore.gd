extends CardScript
## Crimson Manticore — {2}{R}{R} — Creature — Manticore — 2/2 — (4ed, rare)
## Oracle: Flying
##         {R}, {T}: This creature deals 1 damage to target attacking or
##         blocking creature.
##
## Implementation: the Legends archer pattern in red — a tap-and-{R}
## DamageEffect whose target spec carries a GAME-AWARE filter reading the
## live combat declarations, so it is dead weight outside combat.


func build() -> CardData:
	var shot := DamageEffect.new(1)
	shot.target_spec = TargetSpec.creature("target attacking or blocking creature") \
		.with_game_filter(_in_combat)
	return CardData.new("Crimson Manticore", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["manticore"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{R}", true, [shot],
			"{R}, {T}: Crimson Manticore deals 1 damage to target attacking or "
			+ "blocking creature.")) \
		.oracle("Flying\n{R}, {T}: This creature deals 1 damage to target attacking "
			+ "or blocking creature.")


static func _in_combat(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id) or game.combat.blocks.has(inst.id)
