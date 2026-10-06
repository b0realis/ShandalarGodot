extends CardScript
## Dauthi Ghoul — {1}{B} — Creature — Dauthi Zombie (uncommon, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Whenever a creature with shadow dies, put a +1/+1 counter on this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Ghoul", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dauthi","zombie"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhenever a creature with shadow dies, put a +1/+1 counter on this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
