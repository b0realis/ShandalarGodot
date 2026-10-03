extends CardScript
## Necrosavant — {3}{B}{B}{B} — Creature — Zombie Giant (rare, vis).
## Oracle: {3}{B}{B}, Sacrifice a creature: Return this card from your graveyard to the battlefield. Activate only during your upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Necrosavant", "{3}{B}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["zombie","giant"])
	c.oracle("{3}{B}{B}, Sacrifice a creature: Return this card from your graveyard to the battlefield. Activate only during your upkeep.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
