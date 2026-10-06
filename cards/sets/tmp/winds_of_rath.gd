extends CardScript
## Winds of Rath — {3}{W}{W} — Sorcery (rare, tmp).
## Oracle: Destroy all creatures that aren't enchanted. They can't be regenerated.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Winds of Rath", "{3}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures that aren't enchanted. They can't be regenerated.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
