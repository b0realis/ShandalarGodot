extends CardScript
## Corrupt — {5}{B} — Sorcery (common, usg).
## Oracle: Corrupt deals damage to any target equal to the number of Swamps you control. You gain life equal to the damage dealt this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Corrupt", "{5}{B}", Mtg.CardType.SORCERY)
	c.oracle("Corrupt deals damage to any target equal to the number of Swamps you control. You gain life equal to the damage dealt this way.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
