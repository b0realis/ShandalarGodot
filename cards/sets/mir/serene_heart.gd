extends CardScript
## Serene Heart — {1}{G} — Instant (common, mir).
## Oracle: Destroy all Auras.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serene Heart", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Destroy all Auras.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
