extends CardScript
## Bedlam — {2}{R}{R} — Enchantment (rare, usg).
## Oracle: Creatures can't block.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bedlam", "{2}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures can't block.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
