extends CardScript
## Emmessi Tome — {4} — Artifact — Book (rare, tmp).
## Oracle: {5}, {T}: Draw two cards, then discard a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Emmessi Tome", "{4}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("{5}, {T}: Draw two cards, then discard a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
