extends CardScript
## Breach — {2}{B} — Instant (common, usg).
## Oracle: Target creature gets +2/+0 and gains fear until end of turn. (It can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Breach", "{2}{B}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gets +2/+0 and gains fear until end of turn. (It can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
