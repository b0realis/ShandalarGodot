extends CardScript
## Cradle Guard — {1}{G}{G} — Creature — Treefolk (uncommon, usg).
## Oracle: Trample
##         Echo {1}{G}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cradle Guard", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["treefolk"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nEcho {1}{G}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
