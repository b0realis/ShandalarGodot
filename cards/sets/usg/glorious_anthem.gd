extends CardScript
## Glorious Anthem — {1}{W}{W} — Enchantment (rare, usg).
## Oracle: Creatures you control get +1/+1.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Glorious Anthem", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control get +1/+1.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
