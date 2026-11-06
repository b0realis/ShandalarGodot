extends CardScript
## Jasmine Seer — {3}{W} — Creature — Human Wizard (uncommon, uds).
## Oracle: {2}{W}, {T}: Reveal any number of white cards in your hand. You gain 2 life for each card revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jasmine Seer", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{2}{W}, {T}: Reveal any number of white cards in your hand. You gain 2 life for each card revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
