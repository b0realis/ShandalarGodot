extends CardScript
## Call of the Wild — {2}{G}{G} — Enchantment (rare, wth).
## Oracle: {2}{G}{G}: Reveal the top card of your library. If it's a creature card, put it onto the battlefield. Otherwise, put it into your graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Call of the Wild", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}{G}{G}: Reveal the top card of your library. If it's a creature card, put it onto the battlefield. Otherwise, put it into your graveyard.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
