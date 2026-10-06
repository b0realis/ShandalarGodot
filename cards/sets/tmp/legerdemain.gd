extends CardScript
## Legerdemain — {2}{U}{U} — Sorcery (uncommon, tmp).
## Oracle: Exchange control of target artifact or creature and another target permanent that shares one of those types with it. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Legerdemain", "{2}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Exchange control of target artifact or creature and another target permanent that shares one of those types with it. (This effect lasts indefinitely.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
