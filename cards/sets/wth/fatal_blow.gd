extends CardScript
## Fatal Blow — {B} — Instant (common, wth).
## Oracle: Destroy target creature that was dealt damage this turn. It can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fatal Blow", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target creature that was dealt damage this turn. It can't be regenerated.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
