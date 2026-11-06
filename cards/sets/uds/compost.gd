extends CardScript
## Compost — {1}{G} — Enchantment (uncommon, uds).
## Oracle: Whenever a black card is put into an opponent's graveyard from anywhere, you may draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Compost", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a black card is put into an opponent's graveyard from anywhere, you may draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
