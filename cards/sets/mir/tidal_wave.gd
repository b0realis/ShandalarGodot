extends CardScript
## Tidal Wave — {2}{U} — Instant (uncommon, mir).
## Oracle: Create a 5/5 blue Wall creature token with defender. Sacrifice it at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tidal Wave", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Create a 5/5 blue Wall creature token with defender. Sacrifice it at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
