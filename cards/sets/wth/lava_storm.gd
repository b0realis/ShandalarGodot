extends CardScript
## Lava Storm — {3}{R}{R} — Instant (common, wth).
## Oracle: Lava Storm deals 2 damage to each attacking creature or Lava Storm deals 2 damage to each blocking creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lava Storm", "{3}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("Lava Storm deals 2 damage to each attacking creature or Lava Storm deals 2 damage to each blocking creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
