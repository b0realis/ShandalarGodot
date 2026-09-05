extends CardScript
## Orcish Mechanics — {2}{R} — Creature — Orc — 1/1 — (atq, common)
## Oracle: {T}, Sacrifice an artifact: This creature deals 2 damage to any
##         target.
##
## Implementation: a tap-plus-sacrifice DamageEffect aimed at any target.
## Two damage per artifact, once a turn — the red half of Antiquities'
## artifact economy, and a reliable way to cash in a Mox for reach.


func build() -> CardData:
	return CardData.new("Orcish Mechanics", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["orc"]) \
		.activated(ActivatedAbility.new(
			"", true, [DamageEffect.new(2).any_target()],
			"{T}, Sacrifice an artifact: Orcish Mechanics deals 2 damage to any target.") \
			.with_sacrifice_of("artifact", _is_artifact)) \
		.oracle("{T}, Sacrifice an artifact: This creature deals 2 damage to any target.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
