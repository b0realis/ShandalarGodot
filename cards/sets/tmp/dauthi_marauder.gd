extends CardScript
## Dauthi Marauder — {2}{B} — Creature — Dauthi Minion (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Marauder", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["dauthi","minion"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
