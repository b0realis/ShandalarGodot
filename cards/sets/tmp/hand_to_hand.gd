extends CardScript
## Hand to Hand — {2}{R} — Enchantment (rare, tmp).
## Oracle: During combat, players can't cast instant spells or activate abilities that aren't mana abilities.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hand to Hand", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("During combat, players can't cast instant spells or activate abilities that aren't mana abilities.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
