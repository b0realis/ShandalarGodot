extends CardScript
## Merfolk Traders — {1}{U} — Creature — Merfolk (common, wth).
## Oracle: When this creature enters, draw a card, then discard a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Merfolk Traders", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["merfolk"])
	c.oracle("When this creature enters, draw a card, then discard a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
