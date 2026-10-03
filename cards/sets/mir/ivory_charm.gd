extends CardScript
## Ivory Charm — {W} — Instant (common, mir).
## Oracle: Choose one —
##         • All creatures get -2/-0 until end of turn.
##         • Tap target creature.
##         • Prevent the next 1 damage that would be dealt to any target this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ivory Charm", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• All creatures get -2/-0 until end of turn.\n• Tap target creature.\n• Prevent the next 1 damage that would be dealt to any target this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
