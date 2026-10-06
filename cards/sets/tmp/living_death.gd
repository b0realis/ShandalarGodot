extends CardScript
## Living Death — {3}{B}{B} — Sorcery (rare, tmp).
## Oracle: Each player exiles all creature cards from their graveyard, then sacrifices all creatures they control, then puts all cards they exiled this way onto the battlefield.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.
## SIMPLIFIED (docs/simplified-cards.md, "Living Death"): the returned cards enter one after another. See cards/sets/tmp/_misc.gd.

func build() -> CardData:
	var c := CardData.new("Living Death", "{3}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Each player exiles all creature cards from their graveyard, then sacrifices all creatures they control, then puts all cards they exiled this way onto the battlefield.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
