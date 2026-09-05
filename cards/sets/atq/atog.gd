extends CardScript
## Atog — {1}{R} — Creature — Atog — 1/2 — (atq, common)
## Oracle: Sacrifice an artifact: This creature gets +2/+2 until end of turn.
##
## Implementation: a free (no mana, no tap) self PumpEffect whose cost is
## "Sacrifice an artifact" — so the whole board can be eaten in one
## activation chain after blockers are declared. The prototype of every
## later 'Atog.


func build() -> CardData:
	return CardData.new("Atog", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["atog"]) \
		.activated(ActivatedAbility.new(
			"", false,
			[PumpEffect.new(2, 2).self_buff()],
			"Sacrifice an artifact: Atog gets +2/+2 until end of turn.") \
			.with_sacrifice_of("artifact", _is_artifact)) \
		.oracle("Sacrifice an artifact: This creature gets +2/+2 until end of turn.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
