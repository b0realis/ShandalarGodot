extends CardScript
## Thundering Wurm — {2}{G} — Creature — Wurm (Portal, 1997).
## Oracle: When this creature enters, sacrifice it unless you discard a land card.

func build() -> CardData:
	var c := CardData.new("Thundering Wurm", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["wurm"])
	c.oracle("When this creature enters, sacrifice it unless you discard a land card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
