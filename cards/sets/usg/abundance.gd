extends CardScript
## Abundance — {2}{G}{G} — Enchantment (rare, usg).
## Oracle: If you would draw a card, you may instead choose land or nonland and reveal cards from the top of your library until you reveal a card of the chosen kind. Put that card into your hand and put all other cards revealed this way on the bottom of your library in any order.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abundance", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If you would draw a card, you may instead choose land or nonland and reveal cards from the top of your library until you reveal a card of the chosen kind. Put that card into your hand and put all other cards revealed this way on the bottom of your library in any order.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
