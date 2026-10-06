extends CardScript
## Diabolic Edict — {1}{B} — Instant (common, tmp).
## Oracle: Target player sacrifices a creature of their choice.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Diabolic Edict", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("Target player sacrifices a creature of their choice.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
