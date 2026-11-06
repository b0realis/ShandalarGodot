extends CardScript
## Opal Champion — {2}{W} — Enchantment (common, ulg).
## Oracle: When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 3/3 Knight creature with first strike.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opal Champion", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 3/3 Knight creature with first strike.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
