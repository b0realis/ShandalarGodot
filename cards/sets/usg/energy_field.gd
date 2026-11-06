extends CardScript
## Energy Field — {1}{U} — Enchantment (rare, usg).
## Oracle: Prevent all damage that would be dealt to you by sources you don't control.
##         When a card is put into your graveyard from anywhere, sacrifice this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Energy Field", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Prevent all damage that would be dealt to you by sources you don't control.\nWhen a card is put into your graveyard from anywhere, sacrifice this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
