extends CardScript
## Donate — {2}{U} — Sorcery (rare, uds).
## Oracle: Target player gains control of target permanent you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Donate", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Target player gains control of target permanent you control.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
