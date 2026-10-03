extends CardScript
## Urborg Justice — {B}{B} — Instant (rare, wth).
## Oracle: Target opponent sacrifices a creature of their choice for each creature put into your graveyard from the battlefield this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urborg Justice", "{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("Target opponent sacrifices a creature of their choice for each creature put into your graveyard from the battlefield this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
