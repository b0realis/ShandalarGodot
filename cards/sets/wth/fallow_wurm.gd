extends CardScript
## Fallow Wurm — {2}{G} — Creature — Wurm (uncommon, wth).
## Oracle: When this creature enters, sacrifice it unless you discard a land card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fallow Wurm", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["wurm"])
	c.oracle("When this creature enters, sacrifice it unless you discard a land card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
