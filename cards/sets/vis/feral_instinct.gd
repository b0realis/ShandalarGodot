extends CardScript
## Feral Instinct — {1}{G} — Instant (common, vis).
## Oracle: Target creature gets +1/+1 until end of turn.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Feral Instinct", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gets +1/+1 until end of turn.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
