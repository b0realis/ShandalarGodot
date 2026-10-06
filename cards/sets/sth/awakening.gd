extends CardScript
## Awakening — {2}{G}{G} — Enchantment (rare, sth).
## Oracle: At the beginning of each upkeep, untap all creatures and lands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Awakening", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each upkeep, untap all creatures and lands.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
