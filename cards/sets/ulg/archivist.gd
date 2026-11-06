extends CardScript
## Archivist — {2}{U}{U} — Creature — Human Wizard (rare, ulg).
## Oracle: {T}: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Archivist", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}: Draw a card.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
