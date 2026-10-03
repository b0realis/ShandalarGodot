extends CardScript
## Vitalize — {G} — Instant (common, wth).
## Oracle: Untap all creatures you control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vitalize", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Untap all creatures you control.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
