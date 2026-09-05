extends CardScript
## Dragon Engine — {3} — Artifact Creature — Construct — 1/3 — (4ed, rare)
## Oracle: {2}: This creature gets +1/+0 until end of turn.
##
## Implementation: colorless firebreathing (power-only self_buff for {2})
## on an artifact body any deck can run.


func build() -> CardData:
	return CardData.new("Dragon Engine", "{3}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 3) \
		.with_subtypes(["construct"]) \
		.activated(ActivatedAbility.new(
			"{2}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{2}: This creature gets +1/+0 until end of turn.")) \
		.oracle("{2}: This creature gets +1/+0 until end of turn.")
