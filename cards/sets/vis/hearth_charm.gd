extends CardScript
## Hearth Charm — {R} — Instant (common, vis).
## Oracle: Choose one —
##         • Destroy target artifact creature.
##         • Attacking creatures get +1/+0 until end of turn.
##         • Target creature with power 2 or less can't be blocked this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hearth Charm", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Destroy target artifact creature.\n• Attacking creatures get +1/+0 until end of turn.\n• Target creature with power 2 or less can't be blocked this turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
