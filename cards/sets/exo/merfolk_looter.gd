extends CardScript
## Merfolk Looter — {1}{U} — Creature — Merfolk Rogue (common, exo).
## Oracle: {T}: Draw a card, then discard a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Merfolk Looter", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk","rogue"])
	c.oracle("{T}: Draw a card, then discard a card.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
