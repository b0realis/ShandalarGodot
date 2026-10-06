extends CardScript
## Mogg Raider — {R} — Creature — Goblin (common, tmp).
## Oracle: Sacrifice a Goblin: Target creature gets +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Raider", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Sacrifice a Goblin: Target creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
