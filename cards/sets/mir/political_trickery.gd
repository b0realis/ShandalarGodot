extends CardScript
## Political Trickery — {2}{U} — Sorcery (rare, mir).
## Oracle: Exchange control of target land you control and target land an opponent controls. (This effect lasts indefinitely.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Political Trickery", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Exchange control of target land you control and target land an opponent controls. (This effect lasts indefinitely.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
