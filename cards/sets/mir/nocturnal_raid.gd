extends CardScript
## Nocturnal Raid — {2}{B}{B} — Instant (uncommon, mir).
## Oracle: Black creatures get +2/+0 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nocturnal Raid", "{2}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("Black creatures get +2/+0 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
