extends CardScript
## Opal Avenger — {2}{W} — Enchantment (rare, ulg).
## Oracle: When you have 10 or less life, if this permanent is an enchantment, it becomes a 3/5 Soldier creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opal Avenger", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When you have 10 or less life, if this permanent is an enchantment, it becomes a 3/5 Soldier creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
