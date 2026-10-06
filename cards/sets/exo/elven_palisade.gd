extends CardScript
## Elven Palisade — {G} — Enchantment (uncommon, exo).
## Oracle: Sacrifice a Forest: Target attacking creature gets -3/-0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elven Palisade", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice a Forest: Target attacking creature gets -3/-0 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
