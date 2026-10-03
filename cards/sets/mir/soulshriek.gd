extends CardScript
## Soulshriek — {B} — Instant (common, mir).
## Oracle: Target creature you control gets +X/+0 until end of turn, where X is the number of creature cards in your graveyard. Sacrifice that creature at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soulshriek", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Target creature you control gets +X/+0 until end of turn, where X is the number of creature cards in your graveyard. Sacrifice that creature at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
