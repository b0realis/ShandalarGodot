extends CardScript
## Tinker — {2}{U} — Sorcery (uncommon, ulg).
## Oracle: As an additional cost to cast this spell, sacrifice an artifact.
##         Search your library for an artifact card, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tinker", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice an artifact.\nSearch your library for an artifact card, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
