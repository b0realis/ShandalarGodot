extends CardScript
## Shallow Grave — {1}{B} — Instant (rare, mir).
## Oracle: Return the top creature card of your graveyard to the battlefield. That creature gains haste until end of turn. Exile it at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shallow Grave", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("Return the top creature card of your graveyard to the battlefield. That creature gains haste until end of turn. Exile it at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
