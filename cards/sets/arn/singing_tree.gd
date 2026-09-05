extends CardScript
## Singing Tree — {3}{G} — Creature — Plant — 0/3 — (arn, rare)
## Oracle: {T}: Target attacking creature has base power 0 until end of
##         turn.
##
## Implementation: Island of Wak-Wak's effect on a body, aimed with the
## combat-aware "attacking creature" filter. A 0/3 that blanks the
## biggest attacker every turn — Fog on a stick, once per untap.


func build() -> CardData:
	var flatten := SetBasePowerToughnessEffect.new(0, -1,
		TargetSpec.creature("target attacking creature").with_game_filter(_is_attacking))
	return CardData.new("Singing Tree", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 3) \
		.with_subtypes(["plant"]) \
		.activated(ActivatedAbility.new(
			"", true, [flatten],
			"{T}: Target attacking creature has base power 0 until end of turn.")) \
		.oracle("{T}: Target attacking creature has base power 0 until end of turn.")


static func _is_attacking(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id)
