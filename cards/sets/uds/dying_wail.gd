extends CardScript
## Dying Wail — {1}{B} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         When enchanted creature dies, target player discards two cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dying Wail", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen enchanted creature dies, target player discards two cards.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
