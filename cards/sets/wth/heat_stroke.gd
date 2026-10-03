extends CardScript
## Heat Stroke — {2}{R} — Enchantment (rare, wth).
## Oracle: At end of combat, destroy each creature that blocked or was blocked this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heat Stroke", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At end of combat, destroy each creature that blocked or was blocked this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
