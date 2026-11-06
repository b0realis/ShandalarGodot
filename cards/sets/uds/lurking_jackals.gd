extends CardScript
## Lurking Jackals — {B} — Enchantment (uncommon, uds).
## Oracle: When an opponent has 10 or less life, if this permanent is an enchantment, it becomes a 3/2 Jackal creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lurking Jackals", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent has 10 or less life, if this permanent is an enchantment, it becomes a 3/2 Jackal creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
