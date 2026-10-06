extends CardScript
## Soltari Trooper — {1}{W} — Creature — Soltari Soldier (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Whenever this creature attacks, it gets +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Trooper", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["soltari","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhenever this creature attacks, it gets +1/+1 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
