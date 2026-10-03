extends CardScript
## Forbidden Crypt — {3}{B}{B} — Enchantment (rare, mir).
## Oracle: If you would draw a card, return a card from your graveyard to your hand instead. If you can't, you lose the game.
##         If a card would be put into your graveyard from anywhere, exile that card instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Forbidden Crypt", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If you would draw a card, return a card from your graveyard to your hand instead. If you can't, you lose the game.\nIf a card would be put into your graveyard from anywhere, exile that card instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
