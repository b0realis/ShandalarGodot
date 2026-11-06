extends CardScript
## Hibernation — {2}{U} — Instant (uncommon, usg).
## Oracle: Return all green permanents to their owners' hands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hibernation", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Return all green permanents to their owners' hands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
