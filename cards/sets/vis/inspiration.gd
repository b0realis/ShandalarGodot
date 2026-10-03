extends CardScript
## Inspiration — {3}{U} — Instant (common, vis).
## Oracle: Target player draws two cards.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Inspiration", "{3}{U}", Mtg.CardType.INSTANT)
	c.oracle("Target player draws two cards.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
