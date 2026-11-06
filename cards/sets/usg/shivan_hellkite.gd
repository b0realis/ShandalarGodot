extends CardScript
## Shivan Hellkite — {5}{R}{R} — Creature — Dragon (rare, usg).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         {1}{R}: This creature deals 1 damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shivan Hellkite", "{5}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\n{1}{R}: This creature deals 1 damage to any target.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
