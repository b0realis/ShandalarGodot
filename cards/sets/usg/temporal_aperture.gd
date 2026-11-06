extends CardScript
## Temporal Aperture — {2} — Artifact (rare, usg).
## Oracle: {5}, {T}: Shuffle your library, then reveal the top card. Until end of turn, for as long as that card remains on top of your library, play with the top card of your library revealed and you may play that card without paying its mana cost. (If it has X in its mana cost, X is 0.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Temporal Aperture", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{5}, {T}: Shuffle your library, then reveal the top card. Until end of turn, for as long as that card remains on top of your library, play with the top card of your library revealed and you may play that card without paying its mana cost. (If it has X in its mana cost, X is 0.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
