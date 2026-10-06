extends CardScript
## Aluren — {2}{G}{G} — Enchantment (rare, tmp).
## Oracle: Any player may cast creature spells with mana value 3 or less without paying their mana costs and as though they had flash.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aluren", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Any player may cast creature spells with mana value 3 or less without paying their mana costs and as though they had flash.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
