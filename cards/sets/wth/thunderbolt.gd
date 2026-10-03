extends CardScript
## Thunderbolt — {1}{R} — Instant (common, wth).
## Oracle: Choose one —
##         • Thunderbolt deals 3 damage to target player or planeswalker.
##         • Thunderbolt deals 4 damage to target creature with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thunderbolt", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Thunderbolt deals 3 damage to target player or planeswalker.\n• Thunderbolt deals 4 damage to target creature with flying.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
