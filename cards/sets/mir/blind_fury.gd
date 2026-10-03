extends CardScript
## Blind Fury — {2}{R}{R} — Instant (uncommon, mir).
## Oracle: All creatures lose trample until end of turn. If a creature would deal combat damage to a creature this turn, it deals double that damage to that creature instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blind Fury", "{2}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("All creatures lose trample until end of turn. If a creature would deal combat damage to a creature this turn, it deals double that damage to that creature instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
