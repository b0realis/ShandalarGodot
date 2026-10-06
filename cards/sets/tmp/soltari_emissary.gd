extends CardScript
## Soltari Emissary — {1}{W} — Creature — Soltari Soldier (rare, tmp).
## Oracle: {W}: This creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Emissary", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["soltari","soldier"])
	c.oracle("{W}: This creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
