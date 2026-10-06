extends CardScript
## Spontaneous Combustion — {1}{B}{R} — Instant (uncommon, tmp).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Spontaneous Combustion deals 3 damage to each creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spontaneous Combustion", "{1}{B}{R}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nSpontaneous Combustion deals 3 damage to each creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
