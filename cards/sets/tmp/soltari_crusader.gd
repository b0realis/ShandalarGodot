extends CardScript
## Soltari Crusader — {2}{W} — Creature — Soltari Knight (uncommon, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         {1}{W}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Crusader", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["soltari","knight"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\n{1}{W}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
