extends CardScript
## Ruination — {3}{R} — Sorcery (rare, sth).
## Oracle: Destroy all nonbasic lands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ruination", "{3}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all nonbasic lands.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
