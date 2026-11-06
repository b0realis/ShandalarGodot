extends CardScript
## About Face — {R} — Instant (common, ulg).
## Oracle: Switch target creature's power and toughness until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("About Face", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Switch target creature's power and toughness until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
