extends CardScript
## Bereavement — {1}{B} — Enchantment (uncommon, usg).
## Oracle: Whenever a green creature dies, its controller discards a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bereavement", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a green creature dies, its controller discards a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
