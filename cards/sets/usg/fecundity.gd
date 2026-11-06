extends CardScript
## Fecundity — {2}{G} — Enchantment (uncommon, usg).
## Oracle: Whenever a creature dies, that creature's controller may draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fecundity", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature dies, that creature's controller may draw a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
