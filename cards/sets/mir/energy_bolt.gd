extends CardScript
## Energy Bolt — {X}{R}{W} — Sorcery (rare, mir).
## Oracle: Choose one —
##         • Energy Bolt deals X damage to target player or planeswalker.
##         • Target player gains X life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Energy Bolt", "{X}{R}{W}", Mtg.CardType.SORCERY)
	c.oracle("Choose one —\n• Energy Bolt deals X damage to target player or planeswalker.\n• Target player gains X life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
