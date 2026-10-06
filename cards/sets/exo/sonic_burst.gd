extends CardScript
## Sonic Burst — {1}{R} — Instant (common, exo).
## Oracle: As an additional cost to cast this spell, discard a card at random.
##         Sonic Burst deals 4 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sonic Burst", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, discard a card at random.\nSonic Burst deals 4 damage to any target.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
