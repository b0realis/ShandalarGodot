extends CardScript
## Aleatory — {1}{R} — Instant (uncommon, mir).
## Oracle: Cast this spell only during combat after blockers are declared.
##         Flip a coin. If you win the flip, target creature gets +1/+1 until end of turn.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aleatory", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during combat after blockers are declared.\nFlip a coin. If you win the flip, target creature gets +1/+1 until end of turn.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
