extends CardScript
## Aether Tide — {X}{U} — Sorcery (common, exo).
## Oracle: As an additional cost to cast this spell, discard X creature cards.
##         Return X target creatures to their owners' hands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aether Tide", "{X}{U}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, discard X creature cards.\nReturn X target creatures to their owners' hands.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
