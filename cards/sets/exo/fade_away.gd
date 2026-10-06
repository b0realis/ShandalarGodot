extends CardScript
## Fade Away — {2}{U} — Sorcery (common, exo).
## Oracle: For each creature, its controller sacrifices a permanent of their choice unless they pay {1}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fade Away", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("For each creature, its controller sacrifices a permanent of their choice unless they pay {1}.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
