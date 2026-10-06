extends CardScript
## Nausea — {1}{B} — Sorcery (common, exo).
## Oracle: All creatures get -1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nausea", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("All creatures get -1/-1 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
