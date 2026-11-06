extends CardScript
## Shower of Sparks — {R} — Instant (common, usg).
## Oracle: Shower of Sparks deals 1 damage to target creature and 1 damage to target player or planeswalker.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shower of Sparks", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Shower of Sparks deals 1 damage to target creature and 1 damage to target player or planeswalker.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
