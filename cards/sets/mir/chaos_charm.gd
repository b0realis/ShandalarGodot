extends CardScript
## Chaos Charm — {R} — Instant (common, mir).
## Oracle: Choose one —
##         • Destroy target Wall.
##         • Chaos Charm deals 1 damage to target creature.
##         • Target creature gains haste until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chaos Charm", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Destroy target Wall.\n• Chaos Charm deals 1 damage to target creature.\n• Target creature gains haste until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
