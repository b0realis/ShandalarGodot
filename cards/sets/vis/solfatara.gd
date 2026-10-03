extends CardScript
## Solfatara — {2}{R} — Instant (common, vis).
## Oracle: Target player can't play lands this turn.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Solfatara", "{2}{R}", Mtg.CardType.INSTANT)
	c.oracle("Target player can't play lands this turn.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
