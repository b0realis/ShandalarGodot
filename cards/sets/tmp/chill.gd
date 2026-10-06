extends CardScript
## Chill — {1}{U} — Enchantment (uncommon, tmp).
## Oracle: Red spells cost {2} more to cast.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chill", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Red spells cost {2} more to cast.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
