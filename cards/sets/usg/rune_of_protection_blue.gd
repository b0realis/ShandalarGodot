extends CardScript
## Rune of Protection: Blue — {1}{W} — Enchantment (common, usg).
## Oracle: {W}: The next time a blue source of your choice would deal damage to you this turn, prevent that damage.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rune of Protection: Blue", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{W}: The next time a blue source of your choice would deal damage to you this turn, prevent that damage.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
