extends CardScript
## Heartwood Treefolk — {2}{G}{G} — Creature — Treefolk (uncommon, tmp).
## Oracle: Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heartwood Treefolk", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["treefolk"])
	c.with_landwalk(["forest"])
	c.oracle("Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
