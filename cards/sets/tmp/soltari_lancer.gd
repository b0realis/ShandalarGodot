extends CardScript
## Soltari Lancer — {2}{W} — Creature — Soltari Knight (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         This creature has first strike as long as it's attacking.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Lancer", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["soltari","knight"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nThis creature has first strike as long as it's attacking.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
