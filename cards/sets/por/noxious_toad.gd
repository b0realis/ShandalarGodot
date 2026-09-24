extends CardScript
## Noxious Toad — {2}{B} — Creature — Frog (Portal, 1997).
## Oracle: When this creature dies, each opponent discards a card.

func build() -> CardData:
	var c := CardData.new("Noxious Toad", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["frog"])
	c.oracle("When this creature dies, each opponent discards a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
