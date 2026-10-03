extends CardScript
## Inner Sanctum — {1}{W}{W} — Enchantment (rare, wth).
## Oracle: Cumulative upkeep—Pay 2 life. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         Prevent all damage that would be dealt to creatures you control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Inner Sanctum", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep—Pay 2 life. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nPrevent all damage that would be dealt to creatures you control.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
