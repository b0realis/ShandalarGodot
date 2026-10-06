extends CardScript
## Rolling Thunder — {X}{R}{R} — Sorcery (common, tmp).
## Oracle: Rolling Thunder deals X damage divided as you choose among any number of targets.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rolling Thunder", "{X}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Rolling Thunder deals X damage divided as you choose among any number of targets.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
