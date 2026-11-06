extends CardScript
## Harmonic Convergence — {2}{G} — Instant (uncommon, ulg).
## Oracle: Put all enchantments on top of their owners' libraries.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Harmonic Convergence", "{2}{G}", Mtg.CardType.INSTANT)
	c.oracle("Put all enchantments on top of their owners' libraries.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
