extends CardScript
## Polymorph — {3}{U} — Sorcery (rare, mir).
## Oracle: Destroy target creature. It can't be regenerated. Its controller reveals cards from the top of their library until they reveal a creature card. The player puts that card onto the battlefield, then shuffles all other cards revealed this way into their library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Polymorph", "{3}{U}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target creature. It can't be regenerated. Its controller reveals cards from the top of their library until they reveal a creature card. The player puts that card onto the battlefield, then shuffles all other cards revealed this way into their library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
