extends CardScript
## Fool's Tome — {4} — Artifact — Book (rare, tmp).
## Oracle: {2}, {T}: Draw a card. Activate only if you have no cards in hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fool's Tome", "{4}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("{2}, {T}: Draw a card. Activate only if you have no cards in hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
