extends CardScript
## Dregs of Sorrow — {X}{4}{B} — Sorcery (rare, tmp).
## Oracle: Destroy X target nonblack creatures. Draw X cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dregs of Sorrow", "{X}{4}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy X target nonblack creatures. Draw X cards.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
