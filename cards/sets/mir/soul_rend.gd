extends CardScript
## Soul Rend — {1}{B} — Instant (uncommon, mir).
## Oracle: Destroy target creature if it's white. A creature destroyed this way can't be regenerated.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soul Rend", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target creature if it's white. A creature destroyed this way can't be regenerated.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
