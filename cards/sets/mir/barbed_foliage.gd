extends CardScript
## Barbed Foliage — {2}{G}{G} — Enchantment (uncommon, mir).
## Oracle: Whenever a creature attacks you, it loses flanking until end of turn.
##         Whenever a creature without flying attacks you, this enchantment deals 1 damage to it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barbed Foliage", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature attacks you, it loses flanking until end of turn.\nWhenever a creature without flying attacks you, this enchantment deals 1 damage to it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
