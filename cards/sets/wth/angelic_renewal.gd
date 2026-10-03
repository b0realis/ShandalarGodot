extends CardScript
## Angelic Renewal — {1}{W} — Enchantment (common, wth).
## Oracle: Whenever a creature is put into your graveyard from the battlefield, you may sacrifice this enchantment. If you do, return that card to the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Angelic Renewal", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature is put into your graveyard from the battlefield, you may sacrifice this enchantment. If you do, return that card to the battlefield.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
