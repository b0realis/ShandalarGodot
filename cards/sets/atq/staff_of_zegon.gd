extends CardScript
## Staff of Zegon — {4} — Artifact — (atq, common)
## Oracle: {3}, {T}: Target creature gets -2/-0 until end of turn.
##
## Implementation: a negative PumpEffect on a costed tap ability — seven
## mana across two turns to blunt one attacker for one turn. Slow even by
## Antiquities standards, but colourless removal-of-a-sort for any deck.


func build() -> CardData:
	return CardData.new("Staff of Zegon", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true, [PumpEffect.new(-2, 0)],
			"{3}, {T}: Target creature gets -2/-0 until end of turn.")) \
		.oracle("{3}, {T}: Target creature gets -2/-0 until end of turn.")
