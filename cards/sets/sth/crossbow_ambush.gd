extends CardScript
## Crossbow Ambush — {G} — Instant (common, sth).
## Oracle: Creatures you control gain reach until end of turn. (They can block creatures with flying.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crossbow Ambush", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Creatures you control gain reach until end of turn. (They can block creatures with flying.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
