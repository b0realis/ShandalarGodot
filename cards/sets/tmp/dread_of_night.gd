extends CardScript
## Dread of Night — {B} — Enchantment (uncommon, tmp).
## Oracle: White creatures get -1/-1.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dread of Night", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("White creatures get -1/-1.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
