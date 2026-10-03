extends CardScript
## Divine Retribution — {1}{W} — Instant (rare, mir).
## Oracle: Divine Retribution deals damage to target attacking creature equal to the number of attacking creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Divine Retribution", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Divine Retribution deals damage to target attacking creature equal to the number of attacking creatures.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
