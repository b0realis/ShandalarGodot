extends CardScript
## Wake of Destruction — {3}{R}{R}{R} — Sorcery (rare, uds).
## Oracle: Destroy target land and all other lands with the same name as that land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wake of Destruction", "{3}{R}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target land and all other lands with the same name as that land.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
