extends CardScript
## Acidic Soil — {2}{R} — Sorcery (uncommon, usg).
## Oracle: Acidic Soil deals damage to each player equal to the number of lands they control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Acidic Soil", "{2}{R}", Mtg.CardType.SORCERY)
	c.oracle("Acidic Soil deals damage to each player equal to the number of lands they control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
