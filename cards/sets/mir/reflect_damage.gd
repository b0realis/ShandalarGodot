extends CardScript
## Reflect Damage — {3}{R}{W} — Instant (rare, mir).
## Oracle: The next time a source of your choice would deal damage this turn, that damage is dealt to that source's controller instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reflect Damage", "{3}{R}{W}", Mtg.CardType.INSTANT)
	c.oracle("The next time a source of your choice would deal damage this turn, that damage is dealt to that source's controller instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
