extends CardScript
## Kaervek's Hex — {3}{B} — Sorcery (uncommon, mir).
## Oracle: Kaervek's Hex deals 1 damage to each nonblack creature and an additional 1 damage to each green creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kaervek's Hex", "{3}{B}", Mtg.CardType.SORCERY)
	c.oracle("Kaervek's Hex deals 1 damage to each nonblack creature and an additional 1 damage to each green creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
