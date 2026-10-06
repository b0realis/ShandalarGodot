extends CardScript
## Shock — {R} — Instant (common, sth).
## Oracle: Shock deals 2 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shock", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Shock deals 2 damage to any target.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
