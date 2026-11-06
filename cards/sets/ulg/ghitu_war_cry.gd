extends CardScript
## Ghitu War Cry — {2}{R} — Enchantment (uncommon, ulg).
## Oracle: {R}: Target creature gets +1/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ghitu War Cry", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{R}: Target creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
