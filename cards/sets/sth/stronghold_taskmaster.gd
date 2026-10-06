extends CardScript
## Stronghold Taskmaster — {2}{B}{B} — Creature — Giant Minion (uncommon, sth).
## Oracle: Other black creatures get -1/-1.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stronghold Taskmaster", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["giant","minion"])
	c.oracle("Other black creatures get -1/-1.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
