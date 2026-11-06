extends CardScript
## Worship — {3}{W} — Enchantment (rare, usg).
## Oracle: If you control a creature, damage that would reduce your life total to less than 1 reduces it to 1 instead.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Worship", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If you control a creature, damage that would reduce your life total to less than 1 reduces it to 1 instead.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
