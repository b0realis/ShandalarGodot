extends CardScript
## Rofellos's Gift — {G} — Sorcery (common, uds).
## Oracle: Reveal any number of green cards in your hand. Return an enchantment card from your graveyard to your hand for each card revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rofellos's Gift", "{G}", Mtg.CardType.SORCERY)
	c.oracle("Reveal any number of green cards in your hand. Return an enchantment card from your graveyard to your hand for each card revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
