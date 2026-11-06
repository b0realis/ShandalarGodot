extends CardScript
## Goblin Medics — {2}{R} — Creature — Goblin Shaman (common, ulg).
## Oracle: Whenever this creature becomes tapped, it deals 1 damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Medics", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin","shaman"])
	c.oracle("Whenever this creature becomes tapped, it deals 1 damage to any target.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
