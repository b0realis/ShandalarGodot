extends CardScript
## Plow Under — {3}{G}{G} — Sorcery (rare, uds).
## Oracle: Put two target lands on top of their owners' libraries.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Plow Under", "{3}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Put two target lands on top of their owners' libraries.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
