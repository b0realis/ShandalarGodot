extends CardScript
## Soltari Foot Soldier — {W} — Creature — Soltari Soldier (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Foot Soldier", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["soltari","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
