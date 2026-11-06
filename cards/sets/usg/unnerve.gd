extends CardScript
## Unnerve — {3}{B} — Sorcery (common, usg).
## Oracle: Each opponent discards two cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unnerve", "{3}{B}", Mtg.CardType.SORCERY)
	c.oracle("Each opponent discards two cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
