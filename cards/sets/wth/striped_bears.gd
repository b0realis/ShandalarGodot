extends CardScript
## Striped Bears — {3}{G} — Creature — Bear (common, wth).
## Oracle: When this creature enters, draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Striped Bears", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["bear"])
	c.oracle("When this creature enters, draw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
