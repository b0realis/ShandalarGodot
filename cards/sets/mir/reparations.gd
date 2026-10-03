extends CardScript
## Reparations — {1}{W}{U} — Enchantment (rare, mir).
## Oracle: Whenever an opponent casts a spell that targets you or a creature you control, you may draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reparations", "{1}{W}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a spell that targets you or a creature you control, you may draw a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
