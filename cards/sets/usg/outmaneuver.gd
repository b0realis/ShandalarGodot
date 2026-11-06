extends CardScript
## Outmaneuver — {X}{R} — Instant (uncommon, usg).
## Oracle: X target blocked creatures assign their combat damage this turn as though they weren't blocked.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Outmaneuver", "{X}{R}", Mtg.CardType.INSTANT)
	c.oracle("X target blocked creatures assign their combat damage this turn as though they weren't blocked.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
