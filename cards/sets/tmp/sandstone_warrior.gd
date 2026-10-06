extends CardScript
## Sandstone Warrior — {2}{R}{R} — Creature — Human Soldier Warrior (common, tmp).
## Oracle: First strike (This creature deals combat damage before creatures without first strike.)
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sandstone Warrior", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["human","soldier","warrior"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike (This creature deals combat damage before creatures without first strike.)\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
