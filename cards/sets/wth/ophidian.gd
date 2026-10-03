extends CardScript
## Ophidian — {2}{U} — Creature — Snake (common, wth).
## Oracle: Whenever this creature attacks and isn't blocked, you may draw a card. If you do, this creature assigns no combat damage this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ophidian", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["snake"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may draw a card. If you do, this creature assigns no combat damage this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
