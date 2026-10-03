extends CardScript
## Sirocco — {1}{R} — Instant (uncommon, mir).
## Oracle: Target player reveals their hand. For each blue instant card revealed this way, that player discards that card unless they pay 4 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sirocco", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Target player reveals their hand. For each blue instant card revealed this way, that player discards that card unless they pay 4 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
