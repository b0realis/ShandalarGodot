extends CardScript
## Lady Caleria — {3}{G}{G}{W}{W} — Legendary Creature — Elf Archer — 3/6 — (leg, rare)
## Oracle: {T}: Lady Caleria deals 3 damage to target attacking or
##         blocking creature.
##
## Implementation: the archer cycle's top end — three damage a turn, on a
## 3/6 body that survives most of what it shoots. Target spec is the same
## combat-aware filter D'Avenant Archer uses.


func build() -> CardData:
	var shot := DamageEffect.new(3)
	shot.target_spec = TargetSpec.creature("target attacking or blocking creature") \
		.with_game_filter(_in_combat)
	return CardData.new("Lady Caleria", "{3}{G}{G}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(3, 6) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elf", "archer"]) \
		.activated(ActivatedAbility.new(
			"", true, [shot],
			"{T}: Lady Caleria deals 3 damage to target attacking or blocking creature.")) \
		.oracle("{T}: Lady Caleria deals 3 damage to target attacking or blocking creature.")


static func _in_combat(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id) or game.combat.blocks.has(inst.id)
