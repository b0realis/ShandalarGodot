extends CardScript
## Planar Void — {B} — Enchantment (uncommon, usg).
## Oracle: Whenever another card is put into a graveyard from anywhere, exile that card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Planar Void", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever another card is put into a graveyard from anywhere, exile that card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
