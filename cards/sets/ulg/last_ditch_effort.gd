extends CardScript
## Last-Ditch Effort — {R} — Instant (uncommon, ulg).
## Oracle: Sacrifice any number of creatures. Last-Ditch Effort deals that much damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Last-Ditch Effort", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Sacrifice any number of creatures. Last-Ditch Effort deals that much damage to any target.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
