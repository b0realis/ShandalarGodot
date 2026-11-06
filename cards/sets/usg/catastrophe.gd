extends CardScript
## Catastrophe — {4}{W}{W} — Sorcery (rare, usg).
## Oracle: Destroy all lands or all creatures. Creatures destroyed this way can't be regenerated.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Catastrophe", "{4}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all lands or all creatures. Creatures destroyed this way can't be regenerated.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
