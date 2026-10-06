extends CardScript
## Dauthi Slayer — {B}{B} — Creature — Dauthi Soldier (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         This creature attacks each combat if able.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Slayer", "{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["dauthi","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nThis creature attacks each combat if able.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
