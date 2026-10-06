extends CardScript
## Soltari Guerrillas — {2}{R}{W} — Creature — Soltari Soldier (rare, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         {0}: The next time this creature would deal combat damage to an opponent this turn, it deals that damage to target creature instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Guerrillas", "{2}{R}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["soltari","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\n{0}: The next time this creature would deal combat damage to an opponent this turn, it deals that damage to target creature instead.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
