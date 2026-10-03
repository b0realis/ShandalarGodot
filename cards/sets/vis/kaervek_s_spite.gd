extends CardScript
## Kaervek's Spite — {B}{B}{B} — Instant (rare, vis).
## Oracle: As an additional cost to cast this spell, sacrifice all permanents you control and discard your hand.
##         Target player loses 5 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kaervek's Spite", "{B}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice all permanents you control and discard your hand.\nTarget player loses 5 life.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
