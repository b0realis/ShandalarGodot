extends CardScript
## Opportunist — {2}{R} — Creature — Human Soldier (uncommon, tmp).
## Oracle: {T}: This creature deals 1 damage to target creature that was dealt damage this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opportunist", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier"])
	c.oracle("{T}: This creature deals 1 damage to target creature that was dealt damage this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
