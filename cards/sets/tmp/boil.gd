extends CardScript
## Boil — {3}{R} — Instant (uncommon, tmp).
## Oracle: Destroy all Islands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Boil", "{3}{R}", Mtg.CardType.INSTANT)
	c.oracle("Destroy all Islands.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
