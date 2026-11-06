extends CardScript
## Weatherseed Treefolk — {2}{G}{G}{G} — Creature — Treefolk (rare, ulg).
## Oracle: Trample
##         When this creature dies, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Weatherseed Treefolk", "{2}{G}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 3)
	c.with_subtypes(["treefolk"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nWhen this creature dies, return it to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
