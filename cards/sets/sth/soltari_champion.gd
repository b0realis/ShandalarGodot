extends CardScript
## Soltari Champion — {2}{W} — Creature — Soltari Soldier (rare, sth).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Whenever this creature attacks, other creatures you control get +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Champion", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["soltari","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhenever this creature attacks, other creatures you control get +1/+1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
