extends CardScript
## Parch — {1}{R} — Instant (common, ulg).
## Oracle: Choose one —
##         • Parch deals 2 damage to any target.
##         • Parch deals 4 damage to target blue creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Parch", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Parch deals 2 damage to any target.\n• Parch deals 4 damage to target blue creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
