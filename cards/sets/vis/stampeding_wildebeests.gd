extends CardScript
## Stampeding Wildebeests — {2}{G}{G} — Creature — Antelope Beast (uncommon, vis).
## Oracle: Trample (This creature can deal excess combat damage to the player or planeswalker it's attacking.)
##         At the beginning of your upkeep, return a green creature you control to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stampeding Wildebeests", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["antelope","beast"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample (This creature can deal excess combat damage to the player or planeswalker it's attacking.)\nAt the beginning of your upkeep, return a green creature you control to its owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
