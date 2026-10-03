extends CardScript
## Cinder Cloud — {3}{R}{R} — Instant (uncommon, mir).
## Oracle: Destroy target creature. If a white creature dies this way, Cinder Cloud deals damage to that creature's controller equal to the creature's power.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cinder Cloud", "{3}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target creature. If a white creature dies this way, Cinder Cloud deals damage to that creature's controller equal to the creature's power.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
