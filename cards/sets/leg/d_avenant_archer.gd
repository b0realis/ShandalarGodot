extends CardScript
## D'Avenant Archer — {2}{W} — Creature — Human Soldier Archer — 1/2 — (leg, common)
## Oracle: {T}: This creature deals 1 damage to target attacking or
##         blocking creature.
##
## Implementation: a tap-only DamageEffect whose target spec carries a
## GAME-AWARE filter reading the live combat declarations — so the archer
## is dead weight outside combat and refuses any target before attackers
## are declared. The Legends archer cycle (with Tor Wauki and Lady
## Caleria) shares this shape.


func build() -> CardData:
	var shot := DamageEffect.new(1)
	shot.target_spec = TargetSpec.creature("target attacking or blocking creature") \
		.with_game_filter(_in_combat)
	return CardData.new("D'Avenant Archer", "{2}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["human", "soldier", "archer"]) \
		.activated(ActivatedAbility.new(
			"", true, [shot],
			"{T}: D'Avenant Archer deals 1 damage to target attacking or blocking creature.")) \
		.oracle("{T}: This creature deals 1 damage to target attacking or blocking creature.")


static func _in_combat(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id) or game.combat.blocks.has(inst.id)
