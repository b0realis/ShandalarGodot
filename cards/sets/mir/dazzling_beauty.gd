extends CardScript
## Dazzling Beauty — {2}{W} — Instant (common, mir).
## Oracle: Cast this spell only during the declare blockers step.
##         Target unblocked attacking creature becomes blocked. (This spell works on creatures that can't be blocked.)
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dazzling Beauty", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare blockers step.\nTarget unblocked attacking creature becomes blocked. (This spell works on creatures that can't be blocked.)\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
