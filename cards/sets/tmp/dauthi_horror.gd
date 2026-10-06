extends CardScript
## Dauthi Horror — {1}{B} — Creature — Dauthi Horror (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         This creature can't be blocked by white creatures.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Horror", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["dauthi","horror"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nThis creature can't be blocked by white creatures.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
