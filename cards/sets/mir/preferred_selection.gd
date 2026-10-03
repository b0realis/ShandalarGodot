extends CardScript
## Preferred Selection — {2}{G}{G} — Enchantment (rare, mir).
## Oracle: At the beginning of your upkeep, look at the top two cards of your library. You may sacrifice this enchantment and pay {2}{G}{G}. If you do, put one of those cards into your hand. If you don't, put one of those cards on the bottom of your library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Preferred Selection", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, look at the top two cards of your library. You may sacrifice this enchantment and pay {2}{G}{G}. If you do, put one of those cards into your hand. If you don't, put one of those cards on the bottom of your library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
